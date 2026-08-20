#!/usr/bin/env bash
# scrub-gate.sh — zmaterializowany scrub-gate (pre-push): grep rejestru wrażliwych etykiet.
# Zasada (model-dostepu §4.3): scrub to WARUNEK pusha, nie opinia. Ten skrypt czyni go mechanicznym.
#
# REJESTR ŻYJE POZA PUBLICZNYM REPO (sam zawiera wrażliwe etykiety!) — w prywatnej instancji.
# Format rejestru: 1 wzorzec ERE na linię; '#' = komentarz. Instancja utrzymuje własny; klasy obowiązkowe:
#   - nazwy org/projektów/instancji (także jako defaulty narzędzi),
#   - imiona/role agentów + FORMY ODMIENIONE (fleksja: mianownik-only przepuszcza),
#   - wewnętrzne etykiety reguł (etykieta sama potrafi nieść nazwę),
#   - prefiksy id trackera (np. wewnętrzne id beadów),
#   - IP/domeny/ścieżki bezwzględne instancji.
#
# Użycie:
#   tools/scrub-gate.sh <rejestr> [<rewizja-bazowa>]   # skan working-tree (i staged) względem rejestru
# Instalacja jako pre-push (w klonie strefy publicznej):
#   printf '#!/bin/sh\nexec tools/scrub-gate.sh "$SCRUB_REGISTRY"\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push
#   (SCRUB_REGISTRY=/sciezka/do/prywatnego/rejestru w env sesji)
set -eu

REG="${1:-${SCRUB_REGISTRY:-}}"
[ -n "$REG" ] && [ -f "$REG" ] || { echo "[scrub-gate] BRAK REJESTRU (arg1 albo \$SCRUB_REGISTRY) — odmowa (fail-closed)." >&2; exit 2; }

# Wzorce: bez pustych linii i komentarzy.
PAT="$(grep -vE '^[[:space:]]*(#|$)' "$REG" | paste -sd'|' -)"
[ -n "$PAT" ] || { echo "[scrub-gate] Rejestr pusty — odmowa (fail-closed)." >&2; exit 2; }

# Skan: pliki śledzone + staged (tekstowe), z pominięciem samego rejestru gdyby leżał w drzewie.
HITS="$(git ls-files -z | xargs -0 grep -niE "$PAT" -- 2>/dev/null | grep -v "scrub-registry" || true)"

if [ -n "$HITS" ]; then
    echo "[scrub-gate] LEAK — wpisy rejestru w drzewie (push ODRZUCONY):" >&2
    printf '%s\n' "$HITS" >&2
    exit 1
fi
echo "[scrub-gate] CLEAN (rejestr: $(basename "$REG"), wzorców: $(grep -cvE '^[[:space:]]*(#|$)' "$REG"))."
