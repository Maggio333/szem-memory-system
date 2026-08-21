#!/bin/sh
# forum-checkin.sh - deterministyczny per-agent check kanalu koordynacji (ZERO-token).
# Uruchamiany przez scheduler OS (cron / Task Scheduler) co ~60s. NIE budzi agenta bezposrednio:
# ustala, czy sa NIEODCZYTANE posty ISTOTNE dla roli, i zapisuje durable wake-event
# .state/<rola>.wake (+ heartbeat). Agent (async-waiter forum-wake-wait.sh) konsumuje event
# i dopiero wtedy reaguje = zero kosztu w idle. Kursor per rola => brak wspoldzielonego clobberingu.
#
# Kontrakt kursorow (.state/, poza gitem, per-maszyna):
#   <rola>.seen      - SHA ktore rola ODCZYTALA (ustawia agent po przeczytaniu; checker tylko czyta).
#   <rola>.wake      - durable event: istnieje => sa nieodczytane-istotne (checker pisze; agent kasuje po obsludze).
#   <rola>.heartbeat - dowod zycia checkera (pisany co uruchomienie).
#
# Env: WATCH_ROLE (wymagane) | FORUM_DIR (opc., dom. katalog nadrzedny skryptu)
#      | FORUM_REMOTE (opc., dom. "local") | HUMANS (opc., imiona operatorow-ludzi, spacja-sep;
#        ich posty ZAWSZE budza - ustaw wlasne, dom. puste) | WATCH_DOMAINS (opc.) regex domen (content-match w body).
set -eu
ROLE="${WATCH_ROLE:?ustaw WATCH_ROLE=<rola>}"
SELF="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
FO="${FORUM_DIR:-$SELF}"
REMOTE="${FORUM_REMOTE:-local}"
HUMANS="${HUMANS:-}"
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
    au="$(printf '%s' "$base" | awk -F'__' '{print $2}')"
    [ "$au" = "$ROLE" ] && continue                                   # P3: nie budz na wlasne
    case "$f" in *__do-all__*|*__do-"$ROLE"__*) relevant="$relevant $f"; continue;; esac
    hit=0
    for h in $HUMANS; do [ "$au" = "$h" ] && hit=1; done             # P0: operator-czlowiek zawsze budzi
    if [ "$hit" = 0 ] && [ -n "${WATCH_DOMAINS:-}" ]; then
      body="$(git -C "$FO" show "$tip:$f" 2>/dev/null || true)"
      printf '%s' "$body" | grep -qiE "$WATCH_DOMAINS" && hit=1     # P1: content-match domen
    fi
    [ "$hit" = 1 ] && relevant="$relevant $f"
  done
fi

if [ -n "$relevant" ]; then
  { printf 'tip=%s\nseen=%s\nts=%s\nposts:\n' "$tip" "$seen" "$now"
    for f in $relevant; do printf '  %s\n' "$f"; done
  } > "$WAKE_F" 2>/dev/null || true
  n=$(printf '%s' "$relevant" | wc -w | tr -d ' '); st="WAKE(istotne=$n)"
else
  st="idle"
fi
printf '%s role=%s tip=%.7s seen=%.7s %s\n' "$now" "$ROLE" "$tip" "${seen:-0000000}" "$st" > "$HB_F" 2>/dev/null || true
exit 0
