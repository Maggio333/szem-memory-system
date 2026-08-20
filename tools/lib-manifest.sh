# lib-manifest.sh — BEZPIECZNY parser manifestu instancji (bash). Sourcowany przez bootstrap/workspace-builder.
# shellcheck shell=bash
#
# Zamyka finding cold-review #1: `source <manifest>` jako root = wykonanie DOWOLNEGO kodu z manifestu (RCE).
# Manifest to DANE, nie kod: skalary KEY=VALUE (whitelist) + tablice ROLES/SECTORS. Ten parser NIE wykonuje
# treści manifestu — brak `source`/`eval` treści; wartości przypisywane literalnie (printf -v), tablice
# składane z tokenów/cudzysłowów. (Sam ten plik = nasz zaufany kod, więc jego source jest OK.)
#
# Użycie:  . "<dir>/lib-manifest.sh" ; load_manifest "<plik>"  -> ustawia $ROLES[@] $SECTORS[@] + klucze skalarne.

_MANIFEST_KEYS="GITOLITE_USER INSTANCE_HOST AGENT_KEYS_DIR AGENT_OS_USER ADMIN_KEY META_REPO SOFT_REPO FORMATKA_URL INSTANCE_DIR META_READERS SOFT_READERS"

load_manifest() {
  local f="$1" line key val insec=0
  ROLES=(); SECTORS=()
  [ -f "$f" ] || { echo "BLAD: brak manifestu $f" >&2; return 1; }
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$insec" -eq 1 ]; then                                  # wewnątrz wieloliniowego SECTORS=( ... )
      case "$line" in *')'*) insec=0; line="${line%%)*}";; esac
      while [[ "$line" == *'"'*'"'* ]]; do
        val="${line#*\"}"; val="${val%%\"*}"; SECTORS+=("$val"); line="${line#*\"$val\"}"
      done
      continue
    fi
    line="${line%%#*}"                                            # utnij komentarz
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"   # trim
    [ -z "$line" ] && continue
    case "$line" in
      SECTORS=\(*)
        insec=1; line="${line#SECTORS=(}"
        case "$line" in *')'*) insec=0; line="${line%%)*}";; esac
        while [[ "$line" == *'"'*'"'* ]]; do
          val="${line#*\"}"; val="${val%%\"*}"; SECTORS+=("$val"); line="${line#*\"$val\"}"
        done ;;
      ROLES=\(*)
        line="${line#ROLES=(}"; line="${line%)*}"
        read -ra ROLES <<<"$line" ;;
      *=*)
        key="${line%%=*}"; val="${line#*=}"
        val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"   # zdejmij jeden poziom cudzysłowów
        case " $_MANIFEST_KEYS " in
          *" $key "*) printf -v "$key" '%s' "$val" ;;
          *) case "$key" in
               WATCH_DOMAINS_*) printf -v "$key" '%s' "$val" ;;
               *) echo "[manifest] pomijam nieznany klucz: $key" >&2 ;;
             esac ;;
        esac ;;
    esac
  done < "$f"
  # walidacja nazw (nit re-gate Wartownika): odrzuc smieci z prob injection ZANIM trafia do gitolite.conf
  local _r _s _nm
  for _r in "${ROLES[@]}"; do
    case "$_r" in ""|*[!A-Za-z0-9_-]*) echo "BLAD manifest: niepoprawna nazwa roli: '$_r' (dozwolone [A-Za-z0-9_-])" >&2; return 1;; esac
  done
  for _s in "${SECTORS[@]}"; do
    case "$_s" in *"|"*) : ;; *) echo "BLAD manifest: sektor bez formatu nazwa|granica|rw|r: '$_s'" >&2; return 1;; esac
    _nm="${_s%%|*}"
    case "$_nm" in ""|*[!A-Za-z0-9_-]*) echo "BLAD manifest: niepoprawna nazwa sektora: '$_nm' (w '$_s')" >&2; return 1;; esac
  done
}
