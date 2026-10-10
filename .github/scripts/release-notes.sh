#!/usr/bin/env bash
# release-notes.sh <chainner-dir> <nightly-repo> <tag> <notes-file>
#
# Writes the changelog part of a nightly's release notes to <notes-file> and
# prints `key=value` lines for $GITHUB_OUTPUT:
#   head=<sha>      chaiNNer commit this nightly builds
#   prev=<sha>      chaiNNer commit the previous nightly built (may be empty)
#   changed=<bool>  whether chaiNNer has commits since the previous nightly
#
# The range is "since the previous nightly", not "the last 24 hours", so a
# skipped or failed night doesn't drop commits. Each release records the
# commit it built in a hidden marker; releases made before the marker existed
# fall back to the commit main pointed at when they were published.
#
# Needs GH_TOKEN for the GitHub API (release lookup, commit authors).
set -euo pipefail

src="$1"
repo="$2"
tag="$3"
out="$4"
upstream="https://github.com/chaiNNer-org/chaiNNer"
marker_re='<!-- chainner-commit: [0-9a-f]{40} -->'

head="$(git -C "$src" rev-parse HEAD)"

# Previous nightly: the newest release that isn't this run's own tag, so a
# second run on the same day still compares against the day before.
prev_tag="$(gh release list -R "$repo" --exclude-drafts --limit 10 --json tagName \
    --jq ".[].tagName | select(. != \"$tag\")" | head -n 1)"
prev=""
if [ -n "$prev_tag" ]; then
    prev="$(gh release view "$prev_tag" -R "$repo" --json body --jq .body \
        | grep -oE "$marker_re" | grep -oE '[0-9a-f]{40}' | head -n 1 || true)"
    if [ -z "$prev" ] || ! git -C "$src" merge-base --is-ancestor "$prev" "$head" 2>/dev/null; then
        published="$(gh release view "$prev_tag" -R "$repo" --json publishedAt --jq .publishedAt)"
        prev="$(git -C "$src" rev-list -n 1 --first-parent --before="$published" HEAD || true)"
    fi
fi

if [ -n "$prev" ]; then
    range="$prev..$head"
else
    range="$head~20..$head"
fi
mapfile -t commits < <(git -C "$src" log --no-merges --format='%H%x09%s%x09%an' "$range")

short="${head:0:9}"
{
    echo "Built from chaiNNer [\`$short\`]($upstream/commit/$head) on $tag."
    echo
    if [ -n "$prev_tag" ]; then
        echo "## Changes since the $prev_tag nightly"
    else
        echo "## Recent changes"
    fi
    echo
    if [ "${#commits[@]}" -eq 0 ]; then
        echo "No new commits."
    fi
    for line in "${commits[@]}"; do
        IFS=$'\t' read -r sha subject name <<< "$line"
        login="$(gh api "repos/chaiNNer-org/chaiNNer/commits/$sha" --jq '.author.login // empty' 2>/dev/null || true)"
        if [ -n "$login" ]; then who="@$login"; else who="$name"; fi
        # "Subject (#123)" -> "Subject ([#123](.../pull/123))". A bare #123 in
        # this repo's release would link to the nightly repo's own issues.
        if [[ "$subject" =~ ^(.*)\ \(#([0-9]+)\)$ ]]; then
            subject="${BASH_REMATCH[1]} ([#${BASH_REMATCH[2]}]($upstream/pull/${BASH_REMATCH[2]}))"
        else
            subject="$subject ([\`${sha:0:9}\`]($upstream/commit/$sha))"
        fi
        echo "- $subject by $who"
    done
    if [ -n "$prev" ] && [ "${#commits[@]}" -gt 0 ]; then
        echo
        echo "[Full diff]($upstream/compare/${prev:0:12}...${head:0:12})"
    fi
    echo
    echo "<!-- chainner-commit: $head -->"
} > "$out"

echo "head=$head"
echo "prev=$prev"
if [ "$prev" != "$head" ]; then echo "changed=true"; else echo "changed=false"; fi
