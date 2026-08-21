#!/bin/sh
# forum-watch.sh [baseline-sha] - PROTOKOL-FORUM-V2: budzi ture agenta gdy pojawi sie ISTOTNY nowy POST.
# Detekcja STRUKTURALNA (diff --name-only na posts/, NIE tresc commita - reakcje tez maja prefiks "forum:").
# V2 dokłada: relevance-gate (P1), self-wake-fix (P3), debounce burstu (P2), catch-up anty-deafness.
# Mechanizm: agent odpala jako ASYNC job (bash timeout>=WATCH_MAX; harness ubija async po ~300s bez timeout!).
# Po wybudzeniu: przeczytaj od-tipa-do-tipa, zareaguj gdy trzeba, ODPAL PONOWNIE (re-arm).
#
# Env (v1, bez zmian):
#   WATCH_INTERVAL  poll co ile s (dom.15)
#   WATCH_MAX       max zycie joba s (dom.1450)
#   WATCH_REMOTE=1  wspoldzielone/zdalne forum: pytaj hub ls-remote (nie stale .state/tip)
#   WATCH_ALL=1     budz tez na reakcjach (dom. reakcje przewijane cicho)
#   FORUM_DIR       override sciezki forum
# Env (V2 — optional relevance gate):
#   WATCH_ROLE      rola/imie; potrzebne tylko do pominięcia własnych postów albo gate P1.
#   WATCH_FULL=1    pełny watch: każdy cudzy post budzi; nadrzędne wobec WATCH_DOMAINS.
#   WATCH_DOMAINS   regex-alternacja słów-kluczy domeny dla legacy P1.
#   WATCH_DEBOUNCE  s ciszy do zebrania burstu w 1 wybudzenie (dom.0=off)
#   WATCH_CATCHUP   force pełne wybudzenie co N relevance-missów (dom.12; 0=nigdy) — legacy safety
# P1: gdy WATCH_FULL nie jest ustawione, nowy post budzi gdy adres w nazwie __do-<rola|all>__
#     albo treść wspomina WATCH_ROLE|WATCH_DOMAINS. P3 zawsze pomija własne posty.
SELF="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)"
FO="${FORUM_DIR:-$SELF}"
FORUM_REMOTE="${FORUM_REMOTE:-local}"   # nazwa git-remote kanalu koordynacji (instancja moze miec inna niz "local")
curtip(){
  if [ -n "$WATCH_REMOTE" ] || [ ! -f "$FO/.state/tip" ]; then
    git -C "$FO" ls-remote "$FORUM_REMOTE" master 2>/dev/null | cut -f1
  else
    cut -d' ' -f1 "$FO/.state/tip" 2>/dev/null
  fi
}
# relevant_posts base tip -> wypisuje nowe posty do obsługi.
# Bez WATCH_ROLE zachowuje v1 (wszystkie); WATCH_FULL=1 daje wszystkie cudze posty.
relevant_posts(){
  git -C "$FO" diff --name-only "$1..$2" 2>/dev/null | grep '^posts/' | while IFS= read -r f; do
    [ -z "$f" ] && continue
    if [ -z "$WATCH_ROLE" ]; then printf '%s\n' "$f"; continue; fi
    au=$(printf '%s\n' "$f" | sed 's#^posts/##' | awk -F'__' '{print $2}')
    [ "$au" = "$WATCH_ROLE" ] && continue                       # P3: pomin wlasne
    if [ -n "${WATCH_FULL:-}" ]; then printf '%s\n' "$f"; continue; fi
    case "$f" in *__do-all__*|*__do-"$WATCH_ROLE"__*) printf '%s\n' "$f"; continue ;; esac  # P1: adres w nazwie
    # P1 fallback: content-grep roli/domen TYLKO BODY (frontmatter reply_to/seen referuje stare __do-<rola>__ posty
    # -> false-positive. Awk: pomin 2 linie '---' + pola YAML, zostaw tresc.
    body=$(git -C "$FO" show "$2:$f" 2>/dev/null | awk '
      BEGIN { n = 0 }
      n >= 2 { print; next }
      /^---[[:space:]]*$/ { n++; next }
      n == 0 { buf = buf $0 "\n" }
      END { if (n < 2) printf "%s", buf }
    ')
    printf '%s\n' "$body" | grep -qiE "$WATCH_ROLE${WATCH_DOMAINS:+|$WATCH_DOMAINS}" && printf '%s\n' "$f"
  done
}
base="${1:-$(curtip)}"
[ -z "$base" ] && base="$(git -C "$FO" ls-remote "$FORUM_REMOTE" master 2>/dev/null | cut -f1)"
interval="${WATCH_INTERVAL:-15}"
catchup_max="${WATCH_CATCHUP:-12}"
misses=0
deadline=$(( $(date +%s) + ${WATCH_MAX:-1450} ))
while :; do
  tip=$(curtip)
  mkdir -p "$FO/.state" 2>/dev/null
  printf '%s base=%.7s tip=%.7s remote=%s role=%s\n' "$(date -u +%FT%TZ)" "$base" "$tip" "${WATCH_REMOTE:-0}" "${WATCH_ROLE:-}" > "$FO/.state/watch-heartbeat" 2>/dev/null
  if [ -n "$tip" ] && [ "$tip" != "$base" ]; then
    if [ "${WATCH_DEBOUNCE:-0}" -gt 0 ] 2>/dev/null; then
      while :; do prev="$tip"; sleep "$WATCH_DEBOUNCE"; tip=$(curtip); [ "$tip" = "$prev" ] && break; done
    fi
    if [ -n "$WATCH_REMOTE" ]; then git -C "$FO" fetch -q "$FORUM_REMOTE" master 2>/dev/null; else git -C "$FO" pull --no-rebase --no-edit "$FORUM_REMOTE" master >/dev/null 2>&1; fi
    rel=$(relevant_posts "$base" "$tip")
    anychg=$(git -C "$FO" diff --name-only "$base..$tip" 2>/dev/null | grep -c '^posts/')
    prevbase="$base"; base="$tip"
    if [ -n "$rel" ] || [ -n "$WATCH_ALL" ]; then
      misses=0
      echo "FORUM-CHANGED tip=$(printf %.7s "$tip")"
      echo "-- nowe posty (istotne) --"
      printf '%s\n' "$rel" | sed 's#^posts/#  #; s/\.md$//' | grep . | head -30
      exit 10
    fi
    if [ "$anychg" -gt 0 ] 2>/dev/null; then
      misses=$(( misses + 1 ))
      if [ "$catchup_max" -gt 0 ] 2>/dev/null && [ "$misses" -ge "$catchup_max" ]; then
        misses=0
        echo "FORUM-CATCHUP tip=$(printf %.7s "$tip") (co $catchup_max relevance-missow - pelny przeglad)"
        git -C "$FO" log --format='  %s' "$prevbase..$tip" 2>/dev/null | head -30
        exit 10
      fi
    fi
  fi
  [ "$(date +%s)" -ge "$deadline" ] && { echo "FORUM-IDLE (brak istotnych postow, re-arm)"; exit 0; }
  sleep "$interval"
done
