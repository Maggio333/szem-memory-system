#!/usr/bin/env bash
# test-forum-duty.sh — verifies durable checkin -> supervised waiter handoff.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKIN="$ROOT/tools/forum-checkin.sh"
WAITER="$ROOT/tools/forum-wake-wait.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

git init --bare -q "$tmp/forum.git"
git clone -q "$tmp/forum.git" "$tmp/forum"
FO="$tmp/forum"
git -C "$FO" remote rename origin local
git -C "$FO" config user.email ci@example.invalid
git -C "$FO" config user.name ci
mkdir -p "$FO/posts"
printf '%s\n' 'seed' > "$FO/posts/2026-01-01T00-00-00Z__Arek__do-all__seed.md"
git -C "$FO" add posts
git -C "$FO" commit -qm seed
git -C "$FO" push -q local master

WATCH_ROLE=Hart FORUM_DIR="$FO" "$CHECKIN"
test -f "$FO/.state/Hart.seen"
test ! -e "$FO/.state/Hart.wake"

printf '%s\n' 'please review the benchmark' > "$FO/posts/2026-01-01T00-01-00Z__Monter__do-Hart__request.md"
git -C "$FO" add posts
git -C "$FO" commit -qm directed
git -C "$FO" push -q local master
WATCH_ROLE=Hart FORUM_DIR="$FO" "$CHECKIN"
test -f "$FO/.state/Hart.wake"

set +e
wait_output="$(WATCH_ROLE=Hart FORUM_DIR="$FO" WAIT_MAX=1 "$WAITER")"
wait_status=$?
set -e
test "$wait_status" -eq 10
test "${wait_output%%$'\n'*}" = "FORUM-WAKE role=Hart"

wake_tip="$(sed -n 's/^tip=//p' "$FO/.state/Hart.wake")"
printf '%s' "$wake_tip" > "$FO/.state/Hart.seen"
rm "$FO/.state/Hart.wake"
WATCH_ROLE=Hart FORUM_DIR="$FO" "$CHECKIN"
test ! -e "$FO/.state/Hart.wake"
echo "FORUM-DUTY-TEST-OK"
