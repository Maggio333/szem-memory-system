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
#   tools/scrub-gate.sh <rejestr>                 # pre-push: skanuje nowe reachable bloby z stdin ref-update
#   tools/scrub-gate.sh <rejestr> <rewizja>      # ręcznie: skanuje wskazaną rewizję
# Instalacja jako pre-push (w klonie strefy publicznej):
#   printf '#!/bin/sh\nexec tools/scrub-gate.sh "$SCRUB_REGISTRY"\n' > .git/hooks/pre-push && chmod +x .git/hooks/pre-push
#   (SCRUB_REGISTRY=/sciezka/do/prywatnego/rejestru w env sesji)
set -eu
set -o pipefail

ZERO=0000000000000000000000000000000000000000
REG="${1:-${SCRUB_REGISTRY:-}}"
[ -n "$REG" ] && [ -f "$REG" ] || { echo "[scrub-gate] BRAK REJESTRU (arg1 albo \$SCRUB_REGISTRY) — odmowa (fail-closed)." >&2; exit 2; }
# Wzorce: bez pustych linii i komentarzy. Exit 1 grep oznacza pusty wynik; błędy odczytu nadal blokują.
if PAT_LINES="$(grep -vE '^[[:space:]]*(#|$)' "$REG")"; then
    GREP_STATUS=0
else
    GREP_STATUS=$?
fi
[ "$GREP_STATUS" -le 1 ] || { echo "[scrub-gate] Nie można odczytać rejestru — odmowa (fail-closed)." >&2; exit 2; }
PAT="$(printf '%s\n' "$PAT_LINES" | paste -sd'|' -)"
[ -n "$PAT" ] || { echo "[scrub-gate] Rejestr pusty — odmowa (fail-closed)." >&2; exit 2; }

scan_tree() {
    tree_hits="$(git ls-files -z | xargs -0 grep -aniE "$PAT" -- 2>/dev/null | grep -v "scrub-registry" || true)"
    if [ -n "$tree_hits" ]; then
        printf '%s\n' "$tree_hits" >&2
        return 1
    fi
    return 0
}

scan_push() {
    updates=$1
    blob_oids=
    while IFS=' ' read -r local_ref local_oid remote_ref remote_oid; do
        [ -n "$local_ref" ] || continue
        [ -n "$local_oid" ] && [ -n "$remote_ref" ] && [ -n "$remote_oid" ] || {
            echo "[scrub-gate] Nieprawidłowy wpis pre-push — odmowa (fail-closed)." >&2
            return 2
        }
        [ "$local_oid" = "$ZERO" ] && continue

        if [ "$remote_oid" = "$ZERO" ]; then
            objects="$(git rev-list --objects "$local_oid")"
        else
            objects="$(git rev-list --objects "$local_oid" --not "$remote_oid")"
        fi
        new_blobs="$(
            printf '%s\n' "$objects" |
                cut -d' ' -f1 |
                git cat-file --batch-check='%(objectname) %(objecttype)' |
                sed -n 's/ blob$//p'
        )"
        blob_oids="${blob_oids}${new_blobs}"$'\n'
    done <<EOF
$updates
EOF

    [ -n "$blob_oids" ] || return 0
    batch_file="$(mktemp)"
    if ! printf '%s' "$blob_oids" | git cat-file --batch >"$batch_file"; then
        rm -f "$batch_file"
        echo "[scrub-gate] Nie można odczytać nowych obiektów — odmowa (fail-closed)." >&2
        return 2
    fi
    if grep -aqE "$PAT" "$batch_file"; then
        echo "[scrub-gate] LEAK — wzorzec rejestru w nowych blobach pusha (push ODRZUCONY):" >&2
        printf '%s' "$blob_oids" >&2
        rm -f "$batch_file"
        return 1
    fi
    rm -f "$batch_file"
    return 0
}

status=0
if [ -n "${2:-}" ]; then
    scan_push "refs/manual $2 refs/manual $ZERO" || status=$?
elif [ -t 0 ]; then
    scan_tree || status=1
else
    updates="$(cat)"
    if [ -n "$updates" ]; then
        scan_push "$updates" || status=$?
    else
        scan_tree || status=1
    fi
fi

if [ "$status" -ne 0 ]; then
    [ "$status" -eq 2 ] && exit 2
    echo "[scrub-gate] LEAK — wpis rejestru w nowych obiektach pusha (push ODRZUCONY):" >&2
    exit 1
fi
echo "[scrub-gate] CLEAN (rejestr: $(basename "$REG"), wzorców: $(grep -cvE '^[[:space:]]*(#|$)' "$REG"))."
