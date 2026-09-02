#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file=$repo_root/src/frontend/plumos_controller_ui.c

grep -q 'Fonts belong to the managed app layer' "$source_file"
grep -q 'ui->plumos_root,' "$source_file"
grep -q '"fonts/default.otf"' "$source_file"
grep -q '"fonts/cjk-fallback.ttc"' "$source_file"

echo 'bubble_managed_font_root=result-ok owner=app-layer media-independent=yes'
