#!/usr/bin/env bash
# Runs a command, shows its output, and republishes the tail of that output as a
# GitHub annotation so a failure (or the analyzer's infos) can be read through
# the API without downloading logs.
# Usage: ci_step.sh <title> <command...>
title="$1"
shift
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
code="${PIPESTATUS[0]}"
tail_text="$(sed 's/\x1b\[[0-9;]*m//g' "$out" | tail -n 70 | cut -c1-300 | python3 -c "
import sys
s = sys.stdin.read()
print(s.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'), end='')
")"
if [ "$code" -ne 0 ]; then
  echo "::error title=${title} failed::${tail_text}"
  details="$(sed 's/\x1b\[[0-9;]*m//g' "$out" | grep -n -A22 -E '\[E\]|Error:|Exception' | head -n 110 | cut -c1-300 | python3 -c "
import sys
s = sys.stdin.read()
print(s.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'), end='')
")"
  echo "::error title=${title} details::${details}"
else
  echo "::notice title=${title} output::${tail_text}"
fi
exit "$code"
