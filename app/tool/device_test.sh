#!/usr/bin/env bash
# Runs the integration test on the emulator that android-emulator-runner has
# started, and republishes its RESULT lines and any failure as annotations.
cd "$(dirname "$0")/.." || exit 1
log=/tmp/device_test.log
adb wait-for-device
adb shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 2; done'
flutter test integration_test/device_test.dart -d emulator-5554 --no-pub 2>&1 | tee "$log"
code=${PIPESTATUS[0]}

esc() { head -n "${1:-80}" | cut -c1-300 | python3 -c "
import sys
print(sys.stdin.read().replace('%','%25').replace('\r','').replace('\n','%0A'), end='')"; }

results="$(grep -E 'RESULT' "$log" | sed -E 's/^.*RESULT //' | esc 60)"
echo "::notice title=device results::${results}"
if [ "$code" -ne 0 ]; then
  fails="$(grep -v -E ' (INFO|WARNING|ERROR) \[' "$log" | grep -n -B6 -A30 -E 'EXCEPTION|Expected|Actual|Timed out|Some tests failed|FAILED' | esc 110)"
  echo "::error title=device test failed::${fails}"
fi
exit "$code"
