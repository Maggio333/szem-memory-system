#!/bin/sh
# forum-watch-full.sh — canonicalny per-role, pełny one-shot watcher.
# Uruchamiaj jako JEDEN named async process z restart=no. Po exit 10 handler
# czyta seen..tip, zapisuje .state/<rola>.seen i ręcznie go re-armuje.
set -eu

ROLE="${WATCH_ROLE:?ustaw WATCH_ROLE=<rola>}"
case "$ROLE" in *[!A-Za-z0-9_-]*|"") echo "BLAD: WATCH_ROLE musi pasowac do [A-Za-z0-9_-]+" >&2; exit 2;; esac
SELF="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
FO="${FORUM_DIR:-$SELF}"
REMOTE="${FORUM_REMOTE:-local}"
STATE="$FO/.state"
SEEN="$STATE/$ROLE.seen"
mkdir -p "$STATE"

if [ -s "$SEEN" ]; then
  base="$(cat "$SEEN")"
else
  base="$(git -C "$FO" ls-remote "$REMOTE" master 2>/dev/null | cut -f1)"
  [ -n "$base" ] || { echo "BLAD: brak tip remote $REMOTE" >&2; exit 1; }
  printf '%s' "$base" > "$SEEN"
fi

export FORUM_DIR="$FO"
export FORUM_REMOTE="$REMOTE"
export WATCH_REMOTE=1
export WATCH_FULL=1
unset WATCH_DOMAINS
export WATCH_DEBOUNCE="${WATCH_DEBOUNCE:-3}"
export WATCH_INTERVAL="${WATCH_INTERVAL:-5}"
export WATCH_MAX="${WATCH_MAX:-900}"

echo "FORUM-WATCH-READY role=$ROLE mode=full"
exec sh "$SELF/tools/forum-watch.sh" "$base"
