#!/bin/bash
# JUNGLE DASH — double-click to play, full screen, at your screen's full
# resolution. (Pressing Play inside the Godot editor runs the game squeezed
# into the editor's small Game tab instead.)
#   F11 or Cmd+Ctrl+F leaves / re-enters full screen.  Cmd+Q quits.
cd "$(dirname "$0")"
for GODOT in "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
             "/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [ -x "$GODOT" ]; then
    exec "$GODOT" --path "$(pwd)" --fullscreen
  fi
done
echo "Could not find Godot. Put Godot.app in Downloads or Applications."
read -r -p "Press Return to close."
