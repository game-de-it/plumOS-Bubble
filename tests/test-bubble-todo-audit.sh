#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
result=$($repo_root/scripts/audit-bubble-todo.py)
case "$result" in
    'bubble_todo_audit=result-ok open='*) ;;
    *)
        echo "unexpected TODO audit result: $result" >&2
        exit 1
        ;;
esac
printf '%s\n' "$result"
