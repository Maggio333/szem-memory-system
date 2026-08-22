#!/bin/sh
# forum-checkin.sh - deterministyczny per-agent pełny check kanału (ZERO-token).
# Uruchamiany przez scheduler OS (cron / Task Scheduler) co ~60s. NIE budzi agenta bezpośrednio:
# każdy nieprzeczytany cudzy post tworzy durable wake-event
# .state/<rola>.wake (+ heartbeat). Agent (async-waiter forum-wake-wait.sh) konsumuje event
# i dopiero wtedy reaguje = zero kosztu w idle. Kursor per rola => brak wspólnego clobberingu.
#
# Kontrakt kursorow (.state/, poza gitem, per-maszyna):
#   <rola>.seen      - SHA ktore rola ODCZYTALA (ustawia agent po przeczytaniu; checker tylko czyta).
#   <rola>.wake      - durable event: istnieje => sa nieodczytane-istotne (checker pisze; agent kasuje po obsludze).
#   <rola>.heartbeat - dowod zycia checkera (pisany co uruchomienie).
#
# Env: WATCH_ROLE (wymagane; tylko cursor, heartbeat i filtr własnych postów)
#      | FORUM_DIR (opc., dom. katalog nadrzędny skryptu)
#      | FORUM_REMOTE (opc., dom. "local").
set -eu
ROLE="${WATCH_ROLE:?ustaw WATCH_ROLE=<rola>}"
SELF="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
FO="${FORUM_DIR:-$SELF}"
REMOTE="${FORUM_REMOTE:-local}"
ST="$FO/.state"
mkdir -p "$ST" 2>/dev/null || true
SEEN_F="$ST/${ROLE}.seen"; WAKE_F="$ST/${ROLE}.wake"; HB_F="$ST/${ROLE}.heartbeat"
now="$(date -u +%FT%TZ)"

tip="$(git -C "$FO" ls-remote "$REMOTE" master 2>/dev/null | cut -f1)"
if [ -z "$tip" ]; then
  printf '%s role=%s ERROR: brak tip (remote %s nieosiagalny?)\n' "$now" "$ROLE" "$REMOTE" > "$HB_F" 2>/dev/null || true
  exit 0
fi
seen="$(cat "$SEEN_F" 2>/dev/null || true)"

relevant=""
if [ -z "$seen" ]; then
  printf '%s' "$tip" > "$SEEN_F"; seen="$tip"          # pierwszy raz: baseline=tip (nie budz na historii)
elif [ "$seen" != "$tip" ]; then
  git -C "$FO" fetch -q "$REMOTE" master 2>/dev/null || true
  posts="$(git -C "$FO" diff --name-only "$seen..$tip" 2>/dev/null | grep '^posts/' || true)"
  for f in $posts; do
    base="$(basename "$f" .md)"
    author="$(printf '%s' "$base" | awk -F'__' '{print $2}')"
    [ "$author" = "$ROLE" ] && continue  # odpowiedź agenta nie może obudzić jego następnej tury
    relevant="$relevant $f"
  done
fi

if [ -n "$relevant" ]; then
  { printf 'tip=%s\nseen=%s\nts=%s\nposts:\n' "$tip" "$seen" "$now"
    for f in $relevant; do printf '  %s\n' "$f"; done
  } > "$WAKE_F" 2>/dev/null || true
  n=$(printf '%s' "$relevant" | wc -w | tr -d ' '); st="WAKE(posts=$n)"
else
  st="idle"
fi
printf '%s role=%s tip=%.7s seen=%.7s %s\n' "$now" "$ROLE" "$tip" "${seen:-0000000}" "$st" > "$HB_F" 2>/dev/null || true
exit 0
