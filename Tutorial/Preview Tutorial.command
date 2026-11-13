#!/bin/zsh
# Double-click to open the WorkspaceAssistant Full tutorial in your browser.
# Leave this window open while you use the tutorial; close it to stop.
cd "$(dirname "$0")"

# Stop any earlier preview of this tutorial that is still running.
pkill -f "docc preview WorkspaceAssistantFull.docc" 2>/dev/null && sleep 1

# Use the first free port from 8080 upwards.
PORT=8080
while lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; do PORT=$((PORT + 1)); done

URL="http://localhost:$PORT/tutorials/table-of-contents"
echo "Starting the tutorial at $URL …"
(sleep 8 && open "$URL") &
xcrun docc preview WorkspaceAssistantFull.docc --port $PORT \
  --fallback-display-name "WorkspaceAssistant Full" \
  --fallback-bundle-identifier au.edu.uts.WorkspaceAssistantFull.tutorial
