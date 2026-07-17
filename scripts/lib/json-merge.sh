#!/bin/bash
# Merge JSON defaults recursively while preserving unique list entries.

bootstrap_merge_json() {
    local existing_path="$1"
    local incoming_path="$2"
    local output_path="$3"
    local python_bin="$4"

    "$python_bin" - "$existing_path" "$incoming_path" "$output_path" <<'PY'
import json
import pathlib
import sys

existing_path = pathlib.Path(sys.argv[1])
incoming_path = pathlib.Path(sys.argv[2])
output_path = pathlib.Path(sys.argv[3])

existing = json.loads(existing_path.read_text())
incoming = json.loads(incoming_path.read_text())


def merge(existing_value, incoming_value):
    if isinstance(existing_value, dict) and isinstance(incoming_value, dict):
        merged = dict(existing_value)
        for key, value in incoming_value.items():
            if key in merged:
                merged[key] = merge(merged[key], value)
            else:
                merged[key] = value
        return merged

    if isinstance(existing_value, list) and isinstance(incoming_value, list):
        merged = list(existing_value)
        for item in incoming_value:
            if item not in merged:
                merged.append(item)
        return merged

    return incoming_value


output_path.write_text(json.dumps(merge(existing, incoming), indent=2) + "\n")
PY
}
