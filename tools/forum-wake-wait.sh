#!/bin/sh
# forum-wake-wait.sh - cienki async-waiter (wake-bridge) kanalu koordynacji.
# Uruchamiany przez AGENTA jako async job (timeout >= WAIT_MAX). NIE pyta gita - tylko czeka na durable
# wake-event .state/<rola>.wake pisany przez forum-checkin.sh (scheduler OS, deterministycznie co ~60s).
# Rozdziela POLLING (deterministyczny, zero-token, w schedulerze) od WAKE (async-job budzacy ture agenta).
#
# Po wybudzeniu (exit 10) agent: przeczytaj .wake -> zareaguj -> skasuj event + advance kursor:
#   rm .state/<rola>.wake ; printf %s <tip> > .state/<rola>.seen   -> potem RE-ARM tego waitera.
#
# Env: WATCH_ROLE (wymagane) | FORUM_DIR (opc.) | WAIT_MAX (dom.1450) | WAIT_INTERVAL (dom.5).
set -eu
ROLE="${WATCH_ROLE:?ustaw WATCH_ROLE=<rola>}"
SELF="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
FO="${FORUM_DIR:-$SELF}"
WAKE_F="$FO/.state/${ROLE}.wake"
SEEN_F="$FO/.state/${ROLE}.seen"
MAX="${WAIT_MAX:-1450}"; INT="${WAIT_INTERVAL:-5}"
deadline=$(( $(date +%s) + MAX ))
while :; do
  if [ -f "$WAKE_F" ]; then
    # self-heal race stale-wake: checker mogl zapisac .wake ze STARYM seen podczas dlugiej tury agenta;
    # jesli tip z eventu == biezacy seen, agent juz to przeczytal -> nie budz, sprzatnij event.
    wtip=$(sed -n 's/^tip=//p' "$WAKE_F" 2>/dev/null)
    cur=$(cat "$SEEN_F" 2>/dev/null || true)
    if [ -n "$wtip" ] && [ "$wtip" = "$cur" ]; then rm -f "$WAKE_F"; sleep "$INT"; continue; fi
    echo "FORUM-WAKE role=$ROLE"; cat "$WAKE_F" 2>/dev/null || true; exit 10
  fi
  [ "$(date +%s)" -ge "$deadline" ] && { echo "WAIT-IDLE role=$ROLE (re-arm)"; exit 0; }
  sleep "$INT"
done
