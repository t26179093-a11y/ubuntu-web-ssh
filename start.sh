#!/bin/bash
set -e

LINK_FILE="/data/sshx_link.txt"
LOG_FILE="/data/sshx_log.txt"

echo "Starte sshx..."

# Wenn es bereits einen gespeicherten Link gibt:
if [ -f "$LINK_FILE" ]; then
    echo "Verwende gespeicherten Link:"
    cat "$LINK_FILE"
else
    echo "Starte neue sshx-Session..."
    # Starte sshx und speichere den Link aus der Ausgabe
    sshx | tee "$LOG_FILE" | grep -m1 "https://" | tee "$LINK_FILE"
fi

echo "sshx läuft dauerhaft..."
tail -f "$LOG_FILE"
