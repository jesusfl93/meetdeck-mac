#!/usr/bin/env bash
# Instala o actualiza el plugin "Meet Status" en el Stream Deck.
set -euo pipefail
cd "$(dirname "$0")"
PLUGINS="$HOME/Library/Application Support/com.elgato.StreamDeck/Plugins"
NAME=com.fluentdata.meet.sdPlugin

[ -d "$PLUGINS" ] || { echo "No se encontró la app Stream Deck ($PLUGINS)" >&2; exit 1; }
[ -f "plugin/$NAME/imgs/mic-on.png" ] || swift tools/make_icons.swift

rm -rf "${PLUGINS:?}/$NAME"
rsync -a --exclude plugin.log "plugin/$NAME" "$PLUGINS/"
echo "OK plugin instalado en $PLUGINS/$NAME"

# Si el plugin ya estaba corriendo, el Stream Deck lo relanza solo con el código nuevo.
if pkill -f "$NAME/plugin.js"; then
  echo "OK plugin reiniciado"
else
  echo "Reinicia la app Stream Deck para cargar el plugin (primera instalación)"
fi
