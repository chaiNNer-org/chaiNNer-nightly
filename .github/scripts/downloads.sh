#!/usr/bin/env bash
# downloads.sh <nightly-repo> <tag>
#
# Prints a Markdown downloads table for the assets the release actually has,
# so a platform whose build failed is listed as missing instead of linking
# to a 404. Needs GH_TOKEN.
set -euo pipefail

repo="$1"
tag="$2"
base="https://github.com/$repo/releases/download/$tag"

mapfile -t assets < <(gh release view "$tag" -R "$repo" --json assets --jq '.assets[].name')

# link <os-label> <extension> <text>
link() {
    local a
    for a in "${assets[@]}"; do
        if [[ "$a" == chaiNNer-"$1"-nightly.*."$2" ]]; then
            echo "[$3]($base/$a)"
            return
        fi
    done
}

row() {
    local label="$1" cells=() c
    shift
    while [ $# -gt 0 ]; do
        c="$(link "$1" "$2" "$3")"
        [ -n "$c" ] && cells+=("$c")
        shift 3
    done
    if [ "${#cells[@]}" -eq 0 ]; then
        echo "| $label | build failed |"
    else
        local IFS='|'
        echo "| $label | $(printf '%s · ' "${cells[@]}" | sed 's/ · $//') |"
    fi
}

echo "## Downloads"
echo
echo "| Platform | Files |"
echo "|---|---|"
row "Windows" windows-latest exe "Installer (.exe)" windows-latest zip "Portable (.zip)"
row "macOS (Apple Silicon + Intel)" macos-15 dmg "Disk image (.dmg)"
row "Linux" ubuntu-latest deb ".deb" ubuntu-latest rpm ".rpm" ubuntu-latest zip "Portable (.zip)"
