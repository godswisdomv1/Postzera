#!/usr/bin/env bash
# Runs a command, shows its output, and republishes the important part of that
# output as GitHub annotations, so a failure (or the analyzer's findings) can be
# read through the API without downloading logs.
# Usage: ci_step.sh <title> <command...>
title="$1"
shift
out="$(mktemp)"
"$@" 2>&1 | tee "$out"
code="${PIPESTATUS[0]}"

escape() {
  cut -c1-300 | python3 -c "
import sys
s = sys.stdin.read()
print(s.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A'), end='')
"
}
clean() { sed 's/\x1b\[[0-9;]*m//g' "$out"; }

# Errors and warnings first, then the end of the output.
tail_text="$({
  clean | grep -E '^\s*(error|warning) •' | head -n 40
  echo '--'
  clean | tail -n 25
} | escape)"

if [ "$code" -ne 0 ]; then
  echo "::error title=${title} failed::${tail_text}"
  details="$(clean | grep -n -A22 -E '\[E\]|Error:|Exception' | head -n 110 | escape)"
  echo "::error title=${title} details::${details}"
else
  echo "::notice title=${title} output::${tail_text}"
fi
exit "$code"
