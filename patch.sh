#!/usr/bin/env bash
set -e
python3 "$(dirname "$0")/build_current_parent.py" "$@"
