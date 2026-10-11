#!/usr/bin/env bash
# next-tag.sh <nightly-repo> <date>
#
# Prints the tag for a new nightly on <date> (YYYY-MM-DD): <date> for the
# day's first release, then <date>.2, <date>.3, ...
#
# The number is one past the day's highest existing release, so deleting the
# newest release frees its tag for the next run, and deleting an older one
# doesn't put a new build under an old build's name. Releases count, not
# tags: deleting a release leaves its tag behind, and the upload action
# creates the release on a tag that has none.
#
# Needs GH_TOKEN for the GitHub API.
set -euo pipefail

repo="$1"
date="$2"

highest=0
while read -r t; do
    if [ "$t" = "$date" ]; then
        n=1
    elif [[ "$t" =~ ^"$date"\.([0-9]+)$ ]]; then
        n=$((10#${BASH_REMATCH[1]}))
    else
        continue
    fi
    if [ "$n" -gt "$highest" ]; then highest="$n"; fi
done < <(gh release list -R "$repo" --limit 100 --json tagName --jq '.[].tagName')

if [ "$highest" -eq 0 ]; then
    echo "$date"
else
    echo "$date.$((highest + 1))"
fi
