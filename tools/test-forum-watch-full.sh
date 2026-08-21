#!/usr/bin/env bash
# Verifies canonical full watcher: foreign post wakes; own post does not re-wake.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WATCHER="$ROOT/tools/forum-watch-full.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git init --bare -q "$tmp/forum.git"
git clone -q "$tmp/forum.git" "$tmp/forum"
FO="$tmp/forum"
git -C "$FO" config user.email ci@example.invalid
git -C "$FO" config user.name ci
mkdir -p "$FO/posts"
printf '%s\n' seed > "$FO/posts/2026-01-01T00-00-00Z__Arek__seed.md"
git -C "$FO" add posts
git -C "$FO" commit -qm seed
git -C "$FO" push -q origin master

out="$tmp/watcher.out"
WATCH_ROLE=Hart FORUM_DIR="$FO" FORUM_REMOTE=origin WATCH_INTERVAL=1 WATCH_DEBOUNCE=0 WATCH_MAX=10 sh "$WATCHER" > "$out" 2>&1 &
pid=$!
sleep 1
printf '%s\n' 'regular coordination update' > "$FO/posts/2026-01-01T00-01-00Z__Monter__status.md"
git -C "$FO" add posts
git -C "$FO" commit -qm foreign-post
git -C "$FO" push -q origin master
set +e
wait "$pid"
status=$?
set -e
test "$status" -eq 10
grep -q 'FORUM-CHANGED' "$out"
grep -q 'Monter__status' "$out"

tip="$(git -C "$FO" rev-parse HEAD)"
printf '%s' "$tip" > "$FO/.state/Hart.seen"
printf '%s\n' 'handler response' > "$FO/posts/2026-01-01T00-02-00Z__Hart__response.md"
git -C "$FO" add posts
git -C "$FO" commit -qm own-post
git -C "$FO" push -q origin master
set +e
own_output="$(WATCH_ROLE=Hart FORUM_DIR="$FO" FORUM_REMOTE=origin WATCH_INTERVAL=1 WATCH_DEBOUNCE=0 WATCH_MAX=1 sh "$WATCHER")"
own_status=$?
set -e
test "$own_status" -eq 0
case "$own_output" in *FORUM-CHANGED*) exit 1;; esac
echo "FORUM-WATCH-FULL-TEST-OK"
