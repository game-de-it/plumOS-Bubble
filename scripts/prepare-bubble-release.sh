#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=${1:-0.1.0-rc1}
image=${2:-$repo_root/output/image/bubble-frontend-probe/plumOS-Bubble-0.1.0-rc1-full-stack-validation.img}
source_notes=$repo_root/docs/releases/$version.md
source_manifest=${image%/*}/image.manifest
seven_zip=${SEVEN_ZIP:-$(command -v 7zz || command -v 7z || true)}
release_name=plumos-bubble-release-v$version
release_dir=$repo_root/dist/$release_name
stage_dir=$repo_root/dist/.$release_name.incoming
raw_name=plumos-bubble-v$version-sd-image.img
archive_name=plumos-bubble-v$version-sd-image.7z

[ -f "$image" ] || { echo "missing image: $image" >&2; exit 2; }
[ -f "$source_manifest" ] || { echo "missing image manifest: $source_manifest" >&2; exit 2; }
[ -f "$source_notes" ] || { echo "missing release notes: $source_notes" >&2; exit 2; }
[ -n "$seven_zip" ] || { echo "7z or 7zz is required" >&2; exit 2; }
[ -z "$(git -C "$repo_root" status --short)" ] || {
    echo "refusing release preparation from a dirty worktree" >&2
    exit 2
}
[ ! -e "$release_dir" ] || {
    echo "release directory already exists: $release_dir" >&2
    exit 2
}
[ ! -e "$stage_dir" ] || {
    echo "staging directory already exists: $stage_dir" >&2
    exit 2
}

expected_image_sha=$(awk -F= '$1 == "image_sha256" {print $2}' "$source_manifest")
actual_image_sha=$(shasum -a 256 "$image" | awk '{print $1}')
[ "$actual_image_sha" = "$expected_image_sha" ] || {
    echo "image checksum mismatch" >&2
    exit 1
}
grep -q '^source_ref=0a3a3b6$' "$source_manifest"
grep -q '^publishable=no$' "$source_manifest"

mkdir -p "$repo_root/dist" "$stage_dir"
cleanup() {
    rm -f "$stage_dir/$raw_name"
    if [ -d "$stage_dir" ] && [ ! -e "$release_dir" ]; then
        rm -rf "$stage_dir"
    fi
}
trap cleanup EXIT INT TERM

cp "$source_notes" "$stage_dir/RELEASE_NOTES.md"
cp "$source_manifest" "$stage_dir/plumos-bubble-v$version-image-build-manifest.txt"
ln "$image" "$stage_dir/$raw_name"

"$repo_root/scripts/verify-bubble-frontend-probe-image.sh" "$image" \
    >"$stage_dir/plumos-bubble-v$version-image-verify.txt" 2>&1

(cd "$stage_dir" && "$seven_zip" a -t7z -mx=9 -mmt=on "$archive_name" "$raw_name")
rm -f "$stage_dir/$raw_name"
"$seven_zip" t "$stage_dir/$archive_name" >/dev/null
archive_raw_sha=$("$seven_zip" x -so "$stage_dir/$archive_name" "$raw_name" 2>/dev/null | \
    shasum -a 256 | awk '{print $1}')
[ "$archive_raw_sha" = "$actual_image_sha" ] || {
    echo "archive round-trip checksum mismatch" >&2
    exit 1
}

archive_sha=$(shasum -a 256 "$stage_dir/$archive_name" | awk '{print $1}')
release_source_ref=$(git -C "$repo_root" rev-parse HEAD)
{
    printf '%s\n' 'format=plumos-bubble-release-bundle-v1'
    printf 'version=%s\n' "$version"
    printf 'prerelease=no\n'
    printf 'release_source_ref=%s\n' "$release_source_ref"
    printf 'image_source_ref=0a3a3b6\n'
    printf 'image_file=%s\n' "$raw_name"
    printf 'image_sha256=%s\n' "$actual_image_sha"
    printf 'archive_file=%s\n' "$archive_name"
    printf 'archive_sha256=%s\n' "$archive_sha"
    printf 'image_internal_publishable=no\n'
    printf 'promotion=maintainer-accepted-exact-byte-image\n'
    printf 'physical_cold_boots=3\n'
    printf 'user_media_included=no\n'
    printf 'publication_complete=no\n'
} >"$stage_dir/manifest.txt"

printf '%s  %s\n' "$archive_sha" "$archive_name" \
    >"$stage_dir/$archive_name.sha256"
(cd "$stage_dir" && shasum -a 256 \
    RELEASE_NOTES.md \
    manifest.txt \
    "plumos-bubble-v$version-image-build-manifest.txt" \
    "plumos-bubble-v$version-image-verify.txt" \
    "$archive_name" \
    "$archive_name.sha256" >SHA256SUMS)
(cd "$stage_dir" && shasum -a 256 -c SHA256SUMS >/dev/null)

mv "$stage_dir" "$release_dir"
trap - EXIT INT TERM
printf 'bubble_release_prepare=result-ok version=%s dir=%s image_sha256=%s archive_sha256=%s\n' \
    "$version" "$release_dir" "$actual_image_sha" "$archive_sha"
