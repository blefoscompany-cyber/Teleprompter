"""Select an installed iPhone without assuming a runner has a specific model."""
import json
import sys

with open(sys.argv[1], encoding="utf-8") as file:
    catalog = json.load(file)
candidates = []
for runtime, devices in catalog["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.split(".iOS-")[-1].split("-"))
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append((version, device["name"] == "iPhone 16", device["udid"]))
if not candidates:
    sys.exit("No available iPhone simulator on this runner. Send Build-Logs to Codex.")
print(max(candidates)[2])
