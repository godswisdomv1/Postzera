#!/usr/bin/env bash
# Runs inside the emulator: installs the APK, launches the app, waits, and
# republishes the crash log, the app's own log lines and the process state as
# GitHub annotations. Usage: smoke_android.sh <apk> [seconds]
apk="$1"
wait_s="${2:-20}"
pkg=com.zdmgold.postzera

escape() { head -n 80 | cut -c1-260 | python3 -c "
import sys
s = sys.stdin.read()
print(s.replace('%', '%25').replace('\r', '').replace('\n', '%0A'), end='')
"; }

adb wait-for-device
adb shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 2; done'
adb install -r "$apk" 2>&1 | tail -n 3
adb logcat -c
adb shell am start -W -n "$pkg/.MainActivity" 2>&1 | tail -n 8
sleep "$wait_s"

if adb shell pidof "$pkg" >/dev/null 2>&1 && [ -n "$(adb shell pidof "$pkg")" ]; then
  state="RUNNING after ${wait_s}s"
else
  state="PROCESS DEAD after ${wait_s}s"
fi
echo "state: $state"

crash="$(adb logcat -d -b crash 2>&1)"
app="$(adb logcat -d 2>&1 | grep -E "AndroidRuntime|FATAL EXCEPTION|flutter|Flutter|DEBUG|libc|ActivityManager.*($pkg)|Process: $pkg|NoClassDefFound|ClassNotFound|UnsatisfiedLink|IllegalState|SIGSEGV|Abort" | tail -n 120)"

causes="$(printf '%s\n' "$crash" | grep -E "Caused by|FATAL|Process:|ClassNotFound|NoSuchMethod|NoClassDef" | cut -c1-260 | sed -E 's/^[0-9-]+ [0-9:.]+ +[0-9]+ +[0-9]+ [A-Z] [A-Za-z]+: //' | awk '!seen[$0]++' | head -n 25)"
echo "::notice title=smoke state::$state"
echo "::error title=smoke causes::$(printf '%s\n' "$causes" | escape)"
echo "::error title=smoke crash buffer::$(printf '%s\n' "$crash" | escape)"
echo "::error title=smoke app log::$(printf '%s\n' "$app" | escape)"
adb exec-out screencap -p > screen.png 2>/dev/null || true
case "$state" in RUNNING*) exit 0 ;; *) exit 1 ;; esac
