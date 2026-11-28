#!/usr/bin/env bash
# Omarchy Guard — guarded kill for audited agent processes.
#
# The panel never passes a free-form command to a shell. It calls this script
# with a PID, and the script refuses anything that is not a live process owned
# by the current user whose command line still matches a known agent keyword.
#
#   guard-kill.sh <pid>
#
# Prints {"ok":true,"pid":N} on success or {"ok":false,"error":"..."} on
# refusal. Exit 0 on kill, 1 on refusal, 2 on usage errors.

set -uo pipefail
export LC_ALL=C

refuse() {
  printf '{"ok":false,"error":"%s"}\n' "$1"
  exit 1
}

if (($# != 1)); then
  printf '{"ok":false,"error":"usage: guard-kill.sh <pid>"}\n'
  exit 2
fi

pid=$1
if [[ ! $pid =~ ^[0-9]+$ ]]; then
  refuse "PID must be numeric"
fi
if ((pid <= 1)); then
  refuse "refusing to kill PID $pid"
fi
if ((pid == $$)); then
  refuse "refusing to kill the guard helper"
fi
if [[ ! -d /proc/$pid ]]; then
  refuse "process $pid is not running"
fi
if [[ $(stat -c %u "/proc/$pid" 2>/dev/null) != $EUID ]]; then
  refuse "process $pid belongs to another user"
fi

cmdline=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | tr -d '\000-\037')
comm=$(cat "/proc/$pid/comm" 2>/dev/null | tr -d '\000-\037')

# A shell, terminal, editor, or pager that mentions an agent is not the agent.
case $comm in
  zsh | bash | fish | sh | dash | ksh | tcsh | nu | \
    ghostty | kitty | alacritty | foot | wezterm | tmux | screen | \
    vim | nvim | vi | less | more | grep | rg | code | codium | ssh | sshd)
    refuse "process $pid is a shell or UI host, not an agent"
    ;;
esac

if ! grep -qiE '(^|[^a-z])(claude|codex|opencode|gemini|ollama)([^a-z]|$)' <<<"$comm $cmdline"; then
  refuse "process $pid is not a recognised agent"
fi

# Guard against PID reuse between validation and kill.
starttime_before=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $20}')
[[ -n $starttime_before ]] || refuse "could not read process $pid state"

# Recheck the identity immediately before signalling to narrow the PID-reuse
# window. Nothing from the process is interpreted as shell syntax.
[[ -d /proc/$pid ]] || refuse "process $pid is no longer running"
[[ $(stat -c %u "/proc/$pid" 2>/dev/null) == "$EUID" ]] ||
  refuse "process $pid belongs to another user"
starttime_now=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $20}')
[[ $starttime_now == "$starttime_before" ]] || refuse "process $pid changed before it could be killed"
cmdline_now=$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | tr -d '\000-\037')
comm_now=$(cat "/proc/$pid/comm" 2>/dev/null | tr -d '\000-\037')
case $comm_now in
  zsh | bash | fish | sh | dash | ksh | tcsh | nu | \
    ghostty | kitty | alacritty | foot | wezterm | tmux | screen | \
    vim | nvim | vi | less | more | grep | rg | code | codium | ssh | sshd)
    refuse "process $pid changed to a shell or UI host"
    ;;
esac
grep -qiE '(^|[^a-z])(claude|codex|opencode|gemini|ollama)([^a-z]|$)' \
  <<<"$comm_now $cmdline_now" || refuse "process $pid is no longer a recognised agent"

if ! kill -9 "$pid" 2>/dev/null; then
  refuse "could not kill process $pid"
fi

starttime_after=$(sed 's/.*) //' "/proc/$pid/stat" 2>/dev/null | awk '{print $20}')
if [[ -n $starttime_after && $starttime_after != "$starttime_before" ]]; then
  refuse "process $pid changed before it could be killed"
fi

printf '{"ok":true,"pid":%s}\n' "$pid"
