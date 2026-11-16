#!/bin/bash

# Emit the current Superwhisper phase as JSON lines for the bar indicator.
# The indicator expects {"alt": "<state>"} with idle, recording or transcribing.

last=""
while :; do
  state=$(superwhisper status 2>/dev/null | jq -r '.phase // "idle"' 2>/dev/null)
  [[ -n $state ]] || state="idle"
  if [[ $state != "$last" ]]; then
    printf '{"alt":"%s"}\n' "$state"
    last=$state
  fi
  sleep 1
done
