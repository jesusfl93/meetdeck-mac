#!/usr/bin/env bash
# Compila cada src/<Nombre>.applescript como app, la firma ad hoc y la instala.
#   ./build.sh              compila todo
#   ./build.sh MeetMic ...  compila solo las apps indicadas
set -euo pipefail
cd "$(dirname "$0")"
DEST="${DEST:-$HOME/Applications/StreamDeckMeet}"
BUNDLE_PREFIX="${BUNDLE_PREFIX:-com.fluentdata.streamdeck}"
mkdir -p build dist "$DEST"

[ -f icons/MeetMic.png ] || swift tools/make_icons.swift
swiftc -O -o build/audioswitch tools/audioswitch.swift

if [ $# -gt 0 ]; then
  names=("$@")
else
  names=()
  for f in src/Meet*.applescript src/Audio*.applescript; do names+=("$(basename "$f" .applescript)"); done
fi

for name in "${names[@]}"; do
  case "$name" in
    Meet*)  lib=src/lib/meet_common.applescript ;;
    Audio*) lib=src/lib/audio_common.applescript ;;
    *) echo "Prefijo desconocido: $name" >&2; exit 1 ;;
  esac
  app="dist/$name.app"
  cat "$lib" "src/$name.applescript" > "build/$name.applescript"
  rm -rf "$app"
  osacompile -o "$app" "build/$name.applescript"
  [[ "$name" == Audio* ]] && cp build/audioswitch "$app/Contents/Resources/"

  plist="$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :LSUIElement true" "$plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_PREFIX.$name" "$plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $BUNDLE_PREFIX.$name" "$plist"

  codesign --force --deep --sign - "$app"
  rm -rf "${DEST:?}/$name.app" && cp -R "$app" "$DEST/"
  echo "OK $name"
done
