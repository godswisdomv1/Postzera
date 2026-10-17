#!/usr/bin/env bash
# Layer and hygiene checks from blueprint sections 5, 15 and 23.
# Run from anywhere. Prints every offending line and exits 1 on any hit.
# (A plain "! grep" does not fail a CI step under set -e, so this script exists.)
cd "$(dirname "$0")/.." || exit 2
fail=0

check() { # check <description> <pattern> <dir>...
  local desc="$1" pattern="$2"
  shift 2
  local dirs=() d out
  for d in "$@"; do [ -d "$d" ] && dirs+=("$d"); done
  [ "${#dirs[@]}" -eq 0 ] && return 0
  out=$(grep -rnE "$pattern" "${dirs[@]}" 2>/dev/null)
  if [ -n "$out" ]; then
    echo "LAYER VIOLATION: $desc"
    echo "$out"
    fail=1
  fi
}

check "Material or Cupertino import" \
  "package:flutter/(material|cupertino)\.dart|package:(material_ui|cupertino_ui)" \
  lib test
check "core/ imports dart:io, dart:ui or a plugin" \
  "dart:(io|ui)|package:(share_plus|google_mobile_ads|flutter_inapp_purchase|flutter_local_notifications|pro_video_editor|sqlite3|image_picker|file_picker|url_launcher|shared_preferences|path_provider)" \
  lib/core
check "widgets/ or screens/ reaches into platform/" \
  "/platform/" \
  lib/widgets lib/screens
check "hardcoded string inside Text(" \
  "Text\(\s*['\"]" \
  lib/screens lib/widgets
check "TODO, FIXME or UnimplementedError left in code" \
  "TODO|FIXME|UnimplementedError" \
  lib test

if [ "$fail" -eq 0 ]; then echo "Layer checks passed."; fi
exit "$fail"
