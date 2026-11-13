#!/bin/zsh
# Double-click to build "WorkspaceAssistant Full Tutorial.doccarchive" next to this file.
# Participants double-click that archive to open the tutorial in Xcode.
cd "$(dirname "$0")"
OUT="WorkspaceAssistant Full Tutorial.doccarchive"
rm -rf "$OUT"
xcrun docc convert WorkspaceAssistantFull.docc \
  --fallback-display-name "WorkspaceAssistant Full" \
  --fallback-bundle-identifier au.edu.uts.WorkspaceAssistantFull.tutorial \
  --output-dir "$OUT" && echo "\nDone: $OUT" && open -R "$OUT"
