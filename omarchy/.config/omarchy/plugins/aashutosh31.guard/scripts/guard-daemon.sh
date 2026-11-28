#!/usr/bin/env bash
# Omarchy Guard — one-shot system health and security snapshot.
#
# Prints a single JSON object on stdout and exits 0 even when individual
# probes fail. Missing tools, unreadable journals, and root-only SMART data
# are reported as unavailable instead of breaking the widget.
#
#   guard-daemon.sh                full snapshot (default)
#   guard-daemon.sh --fast         agents + temperatures; security from cache
#   guard-daemon.sh --refresh-smart force a SMART rescan
#
# The script never calls sudo, never prompts, and never invokes a shell with
# data it read. All parsing is bounded and every string is length-capped.

set -uo pipefail
export LC_ALL=C
umask 077

MODE=full
REFRESH_SMART=0

usage() {
  cat <<'EOF'
Usage: guard-daemon.sh [--fast|--full] [--refresh-smart]

  --fast            Skip journal and port re-reads when their cache is fresh.
  --full            Read every source (default).
  --refresh-smart   Rescan disk SMART health instead of using the cache.
EOF
}

while (($# > 0)); do
  case $1 in
    --fast) MODE=fast ;;
    --full) MODE=full ;;
    --refresh-smart) REFRESH_SMART=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      printf 'guard-daemon: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

FAILED_SSH_WARN=${GUARD_FAILED_SSH_WARN:-5}
HIGH_CPU=${GUARD_HIGH_CPU:-50}
LONG_SECONDS=${GUARD_LONG_SECONDS:-14400}
SECURITY_TTL=${GUARD_SECURITY_TTL:-30}
SMART_TTL=${GUARD_SMART_TTL:-600}

CACHE_DIR=${GUARD_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-guard}
mkdir -p "$CACHE_DIR" 2>/dev/null
chmod 700 "$CACHE_DIR" 2>/dev/null
SECURITY_FILE="$CACHE_DIR/security.json"
SMART_FILE="$CACHE_DIR/smart.json"

START_MS=$(date +%s%3N 2>/dev/null || echo 0)

have() { command -v -- "$1" >/dev/null 2>&1; }

# Strip control characters and cap the length of anything that came from the
# system before it reaches JSON or the QML text renderer.
sanitize() {
  tr -d '\000-\037' | cut -c1-"${1:-160}"
}

file_age() {
  local mtime
  mtime=$(stat -c %Y "$1" 2>/dev/null) || {
    echo 999999
    return
  }
  echo $(($(date +%s) - mtime))
}

json_array_from_lines() {
  # Reads newline-separated values and emits a JSON string array.
  jq -Rn '[inputs | select(length > 0)]' 2>/dev/null || echo '[]'
}

# Replace secret-shaped text wherever it could slip through from a probe.
redact() {
  sed -E \
    -e 's|/home/[^/[:space:]]*|/home/$USER|g' \
    -e 's/([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}/[REDACTED_MAC]/g' \
    -e 's/(sk-|ghp_|github_pat_|xox[baprs]-)[A-Za-z0-9_-]{8,}/[REDACTED_KEY]/g' \
    -e 's/(api[_-]?key|token|password|secret)=[^ ]+/[REDACTED]/Ig'
}

# Turn a listening address into a port plus a coarse exposure class. Host
# addresses never leave the machine, so a screenshot or public issue cannot
# reveal a LAN, tailnet, or public address.
mask_host() {
  local addr=$1 host port inner rest
  case $addr in
    \[*\]:*)
      inner=${addr#\[}
      inner=${inner%%\]*}
      rest=${addr#*\]}
      port=${rest##*:}
      case $inner in
        ::1) printf '[::1]:%s' "$port" ;;
        ::) printf '*:%s' "$port" ;;
        *) printf '[REDACTED]:%s' "$port" ;;
      esac
      ;;
    *:*)
      port=${addr##*:}
      host=${addr%:*}
      host=${host%%%*}
      case $host in
        0.0.0.0 | '*') printf '*:%s' "$port" ;;
        127.* | localhost) printf 'localhost:%s' "$port" ;;
        ::1) printf '[::1]:%s' "$port" ;;
        *) printf 'x.x.x.x:%s' "$port" ;;
      esac
      ;;
    *)
      printf '%s' "$(printf '%s' "$addr" | sanitize 80)"
      ;;
  esac
}

errors=()
add_error() { errors+=("$1"); }

if ! have jq; then
  printf '{"schemaVersion":1,"generatedAt":"%s","status":"unknown","summary":"jq is required","errors":["jq is required"]}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Agents: AI tooling and background dev processes
# ---------------------------------------------------------------------------
agent_tsv=$(
  # One grep over every cmdline finds the candidates, so a 5 second poll does
  # not fork a process for each row of ps output.
  agent_pids=" "
  while IFS= read -r file; do
    pid=${file#/proc/}
    pid=${pid%/cmdline}
    [[ $pid =~ ^[0-9]+$ ]] && agent_pids+="$pid "
  done < <(grep -laE 'claude|codex|opencode|gemini|ollama' /proc/[0-9]*/cmdline 2>/dev/null)

  shopt -s nocasematch
  ps -eo pid=,pcpu=,pmem=,rss=,etimes=,comm= --sort=-pcpu 2>/dev/null |
    head -n 300 |
    while read -r pid pcpu pmem rss etimes comm; do
      [[ $pid =~ ^[0-9]+$ ]] || continue
      # A shell, terminal, editor, or pager that merely mentions an agent is
      # not the agent. Killing one of those would close the user's session.
      case $comm in
        zsh | bash | fish | sh | dash | ksh | tcsh | nu | \
          ghostty | kitty | alacritty | foot | wezterm | tmux | screen | \
          vim | nvim | vi | less | more | grep | rg | code | codium | ssh | sshd)
          continue
          ;;
      esac

      if [[ " $agent_pids " != *" $pid "* && ! $comm =~ (claude|codex|opencode|gemini|ollama) ]]; then
        continue
      fi

      cmdline=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null)
      if [[ "$comm $cmdline" =~ (claude|codex|opencode|gemini|ollama) ]]; then
        match=${BASH_REMATCH[1],,}
      else
        continue
      fi

      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$pid" "$pcpu" "$pmem" "$rss" "$etimes" "$match" "$(printf '%s' "$comm" | sanitize 40)"
    done | head -n 20
)

agents_json=$(printf '%s\n' "$agent_tsv" | jq -Rn \
  --argjson high "$HIGH_CPU" \
  --argjson long "$LONG_SECONDS" '
  [inputs | select(length > 0) | split("\t") |
   {pid:(.[0]|tonumber), cpu:(.[1]|tonumber), memPercent:(.[2]|tonumber),
    rssKb:(.[3]|tonumber), seconds:(.[4]|tonumber), match:.[5], command:.[6]} |
   . + {highCpu:(.cpu > $high), longRunning:(.seconds > $long)}]' 2>/dev/null) ||
  agents_json='[]'
[[ -n $agents_json ]] || agents_json='[]'
if ! have ps; then add_error "ps is unavailable; agent scan skipped"; fi

agent_count=$(jq 'length' <<<"$agents_json" 2>/dev/null || echo 0)
high_cpu_count=$(jq '[.[] | select(.highCpu)] | length' <<<"$agents_json" 2>/dev/null || echo 0)
long_count=$(jq '[.[] | select(.longRunning)] | length' <<<"$agents_json" 2>/dev/null || echo 0)

# ---------------------------------------------------------------------------
# Security: SSH failures, sudo activity, listening ports
# ---------------------------------------------------------------------------
security_fresh=0
if [[ -s $SECURITY_FILE ]] && (( $(file_age "$SECURITY_FILE") < SECURITY_TTL )); then
  security_fresh=1
fi

if ((!security_fresh)); then
  ssh_failed=0
  sudo_failed=0
  sudo_success=0
  journal_available=false

  if have journalctl; then
    ssh_log=$(timeout 6 journalctl -q \
      -u ssh.service -u sshd.service \
      --since '-24 hours' -o cat --no-pager -n 2000 2>/dev/null)
    ssh_rc=$?
    if ((ssh_rc == 0)); then journal_available=true; fi
    ssh_failed=$(printf '%s\n' "$ssh_log" | grep -c 'Failed password' || true)

    sudo_log=$(timeout 6 journalctl -q _COMM=sudo \
      --since '-24 hours' -o cat --no-pager -n 1000 2>/dev/null)
    sudo_failed=$(printf '%s\n' "$sudo_log" |
      grep -Eic 'authentication failure|incorrect password|not in sudoers|a password is required' || true)
    sudo_success=$(printf '%s\n' "$sudo_log" | grep -c 'COMMAND=' || true)
  else
    add_error "journalctl is unavailable; SSH and sudo events are unknown"
  fi

  ports_tsv=""
  if have ss; then
    ports_tsv=$(ss -H -tulpn 2>/dev/null | head -n 60 | awk '
      {
        proc = $7
        for (i = 8; i <= NF; i++) proc = proc " " $i
        gsub(/\t/, " ", proc)
        printf "%s\t%s\t%s\n", $1, $5, proc
      }' | while IFS=$'\t' read -r proto local proc; do
      printf '%s\t%s\t%s\n' \
        "$(printf '%s' "$proto" | sanitize 8)" \
        "$(mask_host "$local")" \
        "$(printf '%s' "$proc" | redact | sanitize 120)"
    done)
  else
    add_error "ss is unavailable; listening ports are unknown"
  fi

  ports_json=$(printf '%s\n' "$ports_tsv" | jq -Rn '
    [inputs | select(length > 0) | split("\t") |
     {proto:.[0], local:.[1], process:.[2]} |
     . + {loopback:(.local | test("^(127\\.|localhost:|\\[::1\\]|::1|.*%lo[:,])"))}]' 2>/dev/null) || ports_json='[]'
  [[ -n $ports_json ]] || ports_json='[]'

  security_json=$(jq -n \
    --argjson failedSsh "${ssh_failed:-0}" \
    --argjson sudoFailures "${sudo_failed:-0}" \
    --argjson sudoSuccesses "${sudo_success:-0}" \
    --argjson journalAvailable "$journal_available" \
    --argjson ports "$ports_json" '
    {failedSsh:$failedSsh, sshWindow:"24h", journalAvailable:$journalAvailable,
     sudo:{failures:$sudoFailures, successes:$sudoSuccesses, window:"24h"},
     ports:$ports}' 2>/dev/null) || security_json='{}'

  tmp="$CACHE_DIR/.security.$$"
  if printf '%s\n' "$security_json" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$SECURITY_FILE" 2>/dev/null || rm -f "$tmp"
  fi
else
  security_json=$(cat "$SECURITY_FILE" 2>/dev/null) || security_json='{}'
fi
jq -e . >/dev/null 2>&1 <<<"$security_json" || security_json='{}'

failed_ssh=$(jq '.failedSsh // 0' <<<"$security_json" 2>/dev/null || echo 0)

# ---------------------------------------------------------------------------
# Hardware: CPU temperature and battery health
# ---------------------------------------------------------------------------
cpu_temp=null
cpu_label=""
best=-1000

read_temp() {
  local file=$1 label=$2 raw temp
  [[ -r $file ]] || return 1
  raw=$(cat "$file" 2>/dev/null) || return 1
  [[ $raw =~ ^-?[0-9]+$ ]] || return 1
  temp=$((raw / 1000))
  ((temp < -40 || temp > 150)) && return 1
  if ((temp > best)); then
    best=$temp
    cpu_label=$label
  fi
}

# Prefer CPU package sensors, then fall back to any readable thermal zone.
for hw in /sys/class/hwmon/hwmon*; do
  [[ -d $hw ]] || continue
  name=$(cat "$hw/name" 2>/dev/null || echo hwmon)
  case $name in
    *coretemp* | *k10temp* | *zenpower* | *cpu* | *pkg* | *soc*)
      for f in "$hw"/temp*_input; do read_temp "$f" "$name" || true; done
      ;;
  esac
done
if ((best == -1000)); then
  for hw in /sys/class/hwmon/hwmon*; do
    [[ -d $hw ]] || continue
    name=$(cat "$hw/name" 2>/dev/null || echo hwmon)
    for f in "$hw"/temp*_input; do read_temp "$f" "$name" || true; done
  done
fi
if ((best == -1000)); then
  for zone in /sys/class/thermal/thermal_zone*; do
    [[ -d $zone ]] || continue
    type=$(cat "$zone/type" 2>/dev/null || echo thermal)
    read_temp "$zone/temp" "$type" || true
  done
fi
if ((best != -1000)); then cpu_temp=$best; fi

battery_json=$(jq -n '{present:false,status:null,capacity:null,cycles:null,healthPercent:null}')
for bat in /sys/class/power_supply/BAT*; do
  [[ -d $bat ]] || continue
  capacity=$(cat "$bat/capacity" 2>/dev/null || echo null)
  status=$(cat "$bat/status" 2>/dev/null || echo null)
  cycles=$(cat "$bat/cycle_count" 2>/dev/null || echo null)
  [[ $capacity =~ ^[0-9]+$ ]] || capacity=null
  [[ $cycles =~ ^[0-9]+$ ]] || cycles=null
  full=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null || echo "")
  design=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null || echo "")
  health=null
  if [[ $full =~ ^[0-9]+$ && $design =~ ^[0-9]+$ ]] && ((design > 0)); then
    health=$((full * 100 / design))
  fi
  battery_json=$(jq -n \
    --argjson capacity "${capacity:-null}" \
    --argjson cycles "${cycles:-null}" \
    --arg status "${status:-unknown}" \
    --argjson health "$health" '
    {present:true, status:$status, capacity:$capacity, cycles:$cycles,
     healthPercent:$health}') || true
  break
done
jq -e . >/dev/null 2>&1 <<<"$battery_json" || battery_json='{"present":false}'

# ---------------------------------------------------------------------------
# Disks: SMART health, cached so a 5 second bar poll stays cheap
# ---------------------------------------------------------------------------
smart_json='[]'
smart_fresh=0
if [[ -s $SMART_FILE ]] && (( $(file_age "$SMART_FILE") < SMART_TTL )); then
  smart_fresh=1
fi

if ((REFRESH_SMART)) || [[ ! -s $SMART_FILE ]] || { [[ $MODE == full ]] && ((!smart_fresh)); }; then
  disk_tsv=""
  if have smartctl; then
    devices=$(lsblk -dno NAME,TYPE 2>/dev/null |
      awk '$2 == "disk" && $1 !~ /^(zram|loop|ram|sr)[0-9]*$/ {print $1}' | head -n 8)
    for dev in $devices; do
      [[ -n $dev ]] || continue
      out=$(timeout 4 smartctl -H "/dev/$dev" 2>&1)
      rc=$?
      if ! grep -qiE 'PASSED|FAILED|Permission denied|Operation not permitted|Health Status' <<<"$out" &&
        [[ $dev == nvme* ]]; then
        out=$(timeout 4 smartctl -H -d nvme "/dev/$dev" 2>&1)
        rc=$?
      fi

      health=unknown
      detail=""

      if ((rc == 124)); then
        health=timeout
        detail="smartctl timed out"
      elif grep -qiE 'Permission denied|Operation not permitted' <<<"$out"; then
        health=permission-denied
        detail="run smartctl as root to read this disk"
      elif grep -qi 'FAILED' <<<"$out"; then
        health=failed
        detail=$(grep -m1 -iE 'overall-health|health status' <<<"$out" | redact | sanitize 160)
      elif grep -qiE 'PASSED|SMART Health Status: OK' <<<"$out"; then
        health=passed
        detail=$(grep -m1 -iE 'overall-health|health status' <<<"$out" | redact | sanitize 160)
      elif grep -qiE 'Unable to detect device type|Unknown USB bridge' <<<"$out"; then
        health=unsupported
        detail="device type not recognised by smartctl"
      fi

      [[ -n $detail ]] || detail=$(printf '%s\n' "$out" | tail -n 1 | redact | sanitize 160)
      disk_tsv+="$dev"$'\t'"$health"$'\t'"$detail"$'\n'
    done
  else
    add_error "smartctl is unavailable; disk health is unknown"
  fi

  smart_json=$(printf '%s' "$disk_tsv" | jq -Rn '
    [inputs | select(length > 0) | split("\t") |
     {device:.[0], health:.[1], detail:.[2]}]' 2>/dev/null) || smart_json='[]'
  [[ -n $smart_json ]] || smart_json='[]'

  tmp="$CACHE_DIR/.smart.$$"
  if printf '%s\n' "$smart_json" >"$tmp" 2>/dev/null; then
    mv -f "$tmp" "$SMART_FILE" 2>/dev/null || rm -f "$tmp"
  fi
elif [[ -s $SMART_FILE ]]; then
  smart_json=$(cat "$SMART_FILE" 2>/dev/null) || smart_json='[]'
fi
jq -e 'type == "array"' >/dev/null 2>&1 <<<"$smart_json" || smart_json='[]'

# ---------------------------------------------------------------------------
# System load: CPU delta, memory, and 1 minute load
# ---------------------------------------------------------------------------
SYS_FILE="$CACHE_DIR/system.json"
cpu_percent=null
mem_percent=null
mem_total_mb=null
mem_used_mb=null
load1=null

if [[ -r /proc/stat ]]; then
  read -r _ su sn ss sidle siow sirq ssirq ssteal _rest </proc/stat
  cpu_total=$((su + sn + ss + sidle + siow + sirq + ssirq + ssteal))
  cpu_idle=$((sidle + siow))

  prev_total=""
  prev_idle=""
  if [[ -s $SYS_FILE ]]; then
    read -r prev_total prev_idle _prev_ts <"$SYS_FILE" 2>/dev/null || true
  fi
  if [[ $prev_total =~ ^[0-9]+$ && $prev_idle =~ ^[0-9]+$ ]] &&
    ((cpu_total > prev_total)) && ((cpu_idle >= prev_idle)); then
    diff_total=$((cpu_total - prev_total))
    diff_idle=$((cpu_idle - prev_idle))
    cpu_percent=$(((100 * (diff_total - diff_idle) + diff_total / 2) / diff_total))
  fi

  sys_tmp="$CACHE_DIR/.system.$$"
  if printf '%s %s %s\n' "$cpu_total" "$cpu_idle" "$(date +%s)" >"$sys_tmp" 2>/dev/null; then
    mv -f "$sys_tmp" "$SYS_FILE" 2>/dev/null || rm -f "$sys_tmp"
  fi
fi

if [[ -r /proc/meminfo ]]; then
  mem_total_kb=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
  mem_avail_kb=$(awk '/^MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null)
  if [[ $mem_total_kb =~ ^[0-9]+$ && $mem_avail_kb =~ ^[0-9]+$ ]] && ((mem_total_kb > 0)); then
    mem_total_mb=$((mem_total_kb / 1024))
    mem_used_mb=$(((mem_total_kb - mem_avail_kb) / 1024))
    mem_percent=$(((mem_total_kb - mem_avail_kb) * 100 / mem_total_kb))
  fi
fi

if [[ -r /proc/loadavg ]]; then
  raw_load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
  [[ $raw_load =~ ^[0-9]+(\.[0-9]+)?$ ]] && load1=$raw_load
fi

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------
status=secure
reasons_tsv=""

disk_failed=$(jq '[.[] | select(.health == "failed")] | length' <<<"$smart_json" 2>/dev/null || echo 0)
disk_warning=$(jq '[.[] | select(.health == "warning")] | length' <<<"$smart_json" 2>/dev/null || echo 0)
if ((disk_failed > 0)); then
  status=alert
  reasons_tsv+=$'A disk reports a failing SMART health status\n'
elif ((disk_warning > 0)); then
  status=warning
  reasons_tsv+=$'A disk reports a SMART warning\n'
fi
if ((failed_ssh > FAILED_SSH_WARN)); then
  [[ $status == secure ]] && status=warning
  reasons_tsv+="More than $FAILED_SSH_WARN failed SSH attempts in 24h"$'\n'
fi
if ((high_cpu_count > 0)); then
  [[ $status == secure ]] && status=warning
  reasons_tsv+="$high_cpu_count agent process(es) above ${HIGH_CPU}% CPU"$'\n'
fi
if ((long_count > 0)); then
  [[ $status == secure ]] && status=warning
  reasons_tsv+="$long_count agent process(es) running over $((LONG_SECONDS / 3600))h"$'\n'
fi

reasons_json=$(printf '%s' "$reasons_tsv" | json_array_from_lines)
errors_json=$(printf '%s\n' "${errors[@]:-}" | json_array_from_lines)

if ((agent_count > 0)); then
  summary="$status · $agent_count agent(s) active"
else
  summary="$status · no agents active"
fi

END_MS=$(date +%s%3N 2>/dev/null || echo 0)
duration_ms=$((END_MS - START_MS))

jq -n \
  --arg generatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg mode "$MODE" \
  --arg status "$status" \
  --arg summary "$summary" \
  --argjson durationMs "$duration_ms" \
  --argjson agents "$agents_json" \
  --argjson security "$security_json" \
  --argjson disks "$smart_json" \
  --argjson battery "$battery_json" \
  --argjson cpuTemp "$cpu_temp" \
  --arg cpuLabel "$cpu_label" \
  --argjson cpuPercent "$cpu_percent" \
  --argjson memPercent "$mem_percent" \
  --argjson memTotalMb "$mem_total_mb" \
  --argjson memUsedMb "$mem_used_mb" \
  --argjson load1 "$load1" \
  --argjson reasons "$reasons_json" \
  --argjson errors "$errors_json" '
  {schemaVersion:1, generatedAt:$generatedAt, mode:$mode, durationMs:$durationMs,
   status:$status, summary:$summary, reasons:$reasons,
   agents:{count:($agents|length), highCpu:([$agents[]|select(.highCpu)]|length),
           longRunning:([$agents[]|select(.longRunning)]|length), list:$agents},
   security:$security,
   hardware:{cpuTempC:$cpuTemp, cpuLabel:$cpuLabel, disks:$disks, battery:$battery},
   system:{cpuPercent:$cpuPercent, memPercent:$memPercent, memTotalMb:$memTotalMb,
           memUsedMb:$memUsedMb, load1:$load1},
   errors:$errors}
  | walk(if type == "string" then
      gsub("/home/[^/[:space:]]+"; "/home/$USER")
      | gsub("(?<![0-9])([0-9]{1,3}\\.){3}[0-9]{1,3}(?![0-9])"; "[REDACTED_IP]")
      | gsub("([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}"; "[REDACTED_MAC]")
      | gsub("(sk-|ghp_|github_pat_|xox[baprs]-)[A-Za-z0-9_-]{8,}"; "[REDACTED_KEY]")
      | gsub("(?i)(api[_-]?key|token|password|secret)=[^ ]+"; "[REDACTED]")
    else . end)' 2>/dev/null || printf '%s\n' \
  '{"schemaVersion":1,"status":"unknown","summary":"snapshot failed","errors":["could not assemble JSON"]}'
