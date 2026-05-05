#!/usr/bin/env bash
set -euo pipefail

CHROME_APP="${CHROME_APP:-Google Chrome}"
LOCAL_STATE="${1:-$HOME/Library/Application Support/Google/Chrome/Local State}"

if [[ ! -f "$LOCAL_STATE" ]]; then
  echo "Chrome Local State file was not found:"
  echo "  $LOCAL_STATE"
  exit 1
fi

echo "Force quitting $CHROME_APP..."
osascript -e "tell application \"$CHROME_APP\" to quit" >/dev/null 2>&1 || true
sleep 2

if pgrep -x "$CHROME_APP" >/dev/null 2>&1; then
  pkill -TERM -x "$CHROME_APP" >/dev/null 2>&1 || true
  sleep 1
fi

if pgrep -x "$CHROME_APP" >/dev/null 2>&1; then
  pkill -KILL -x "$CHROME_APP" >/dev/null 2>&1 || true
  sleep 1
fi

BACKUP_PATH="${LOCAL_STATE}.backup.$(date +%Y%m%d-%H%M%S)"
cp -p "$LOCAL_STATE" "$BACKUP_PATH"
echo "Backup saved to:"
echo "  $BACKUP_PATH"

python3 - "$LOCAL_STATE" <<'PY'
import json
import os
import sys
import tempfile

path = os.path.abspath(sys.argv[1])

with open(path, "r", encoding="utf-8") as source:
    data = json.load(source)

original_mode = os.stat(path).st_mode & 0o7777

updated = []


def update_chrome_flags(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key == "variations_permanent_consistency_country":
                if isinstance(child, list):
                    if len(child) >= 2:
                        child[1] = "us"
                    else:
                        child.append("us")
                else:
                    value[key] = ["", "us"]
                updated.append(key)
            elif key == "variations_country":
                value[key] = "us"
                updated.append(key)
            elif key == "is_glic_eligible":
                value[key] = True
                updated.append(key)
            else:
                update_chrome_flags(child)
    elif isinstance(value, list):
        for item in value:
            update_chrome_flags(item)


update_chrome_flags(data)

if "variations_permanent_consistency_country" not in updated:
    data["variations_permanent_consistency_country"] = ["", "us"]
    updated.append("variations_permanent_consistency_country")

if "variations_country" not in updated:
    data["variations_country"] = "us"
    updated.append("variations_country")

if "is_glic_eligible" not in updated:
    data["is_glic_eligible"] = True
    updated.append("is_glic_eligible")

directory = os.path.dirname(path)
fd, temp_path = tempfile.mkstemp(prefix=".Local State.", dir=directory, text=True)

try:
    with os.fdopen(fd, "w", encoding="utf-8") as target:
        json.dump(data, target, ensure_ascii=False, indent=2)
        target.write("\n")
    os.chmod(temp_path, original_mode)
    os.replace(temp_path, path)
finally:
    if os.path.exists(temp_path):
        os.unlink(temp_path)

print("Updated keys:")
for key in sorted(set(updated)):
    print(f"  {key}")
PY

echo "Opening $CHROME_APP..."
open -a "$CHROME_APP"
echo "Done."
