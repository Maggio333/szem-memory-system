#!/usr/bin/env bash
# run-agent.sh — uruchamia agenta Szem w harnessie Omp (domkniecie kroku 5 QUICKSTART jedna komenda).
#
# Sklada krok 5 QUICKSTART (watcher.env + GIT_SSH_COMMAND + omp --profile) w jedno wywolanie na
# workspace zbudowanym krokiem 4 (workspace-builder.sh). W trybie JEDNOPROCESOWYM (adapter-omp.md §3b)
# odpalasz tym TYLKO orkiestratora — role sa subagentami harnessu, nie osobnymi procesami omp;
# tryb multi-pane (QUICKSTART 5b) to osobne wywolanie per agent/pane.
#
# Uzycie:   bash run-agent.sh <manifest.conf> <agent_slug>
#   <agent_slug> to slug uzyty w kroku 4 (workspace-builder.sh) — istnieje $INSTANCE_DIR/agenci/<slug>.
# Wymaga:   Linux/WSL, omp w PATH, workspace zbudowany krokiem 4. Windows: uzyj tools/start.bat run.
set -euo pipefail

# gap#5 (test zrozumialosci): z git-bash Windows bash routuje przez WSL-relay i pada. Twardy stop:
[ "$(uname -s)" = Linux ] || { echo "BLAD: uruchom w WSL/Linux (wpisz: wsl), NIE z git-bash Windows. Windows-entry: tools/start.bat run." >&2; exit 1; }

MANIFEST="${1:?usage: bash run-agent.sh <manifest.conf> <agent_slug>}"
AGENT="${2:?podaj agent_slug (A-Za-z0-9, _, -)}"
[ -f "$MANIFEST" ] || { echo "BLAD: brak manifestu $MANIFEST" >&2; exit 1; }
# shellcheck disable=SC1090
. "$(cd "$(dirname "$0")" && pwd)/lib-manifest.sh"
load_manifest "$MANIFEST"
: "${INSTANCE_DIR:=./instancja}"
log(){ printf '[run-agent] %s\n' "$*"; }
die(){ printf '[run-agent][BLAD] %s\n' "$*" >&2; exit 1; }

# ta sama regula slug co workspace-builder.sh — jeden kontrakt nazw w calym pipeline
case "$AGENT" in
  [A-Za-z0-9]*)
    [[ "$AGENT" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "agent_slug '$AGENT' musi pasowac do [A-Za-z0-9][A-Za-z0-9_-]*"
    ;;
  *) die "agent_slug '$AGENT' musi zaczynac sie od A-Za-z0-9" ;;
esac

# --- workspace z kroku 4 musi istniec w komplecie (profil, watcher, klucz-wskaznik) ---
WS="$INSTANCE_DIR/agenci/$AGENT"
[ -d "$WS" ] || die "brak workspace $WS — najpierw krok 4: bash workspace-builder.sh $MANIFEST $AGENT <agent_id> <rola>"
for f in profil.yml watcher.env ssh-config; do
  [ -f "$WS/$f" ] || die "workspace $WS niekompletny: brak $f — przebuduj krokiem 4 (workspace-builder.sh)"
done

# --- omp musi byc w PATH ---
command -v omp >/dev/null 2>&1 || die "brak omp w PATH — zainstaluj harness Omp (Oh My Pi) i upewnij sie, ze komenda 'omp' dziala w tym WSL/Linux"

WS_ABS="$(cd "$WS" && pwd)"
log "workspace: $WS_ABS"

# --- krok 5 QUICKSTART w jednej komendzie: watcher-env + klucz roli + omp z profilem ---
# shellcheck disable=SC1091
. "$WS_ABS/watcher.env"
export GIT_SSH_COMMAND="ssh -F $WS_ABS/ssh-config"
log "start: omp --profile=$AGENT (przy starcie sesji: profil-check wg rejestr-kluczy.md)"
exec omp --profile="$AGENT" --cwd="$WS_ABS" --append-system-prompt="$WS_ABS/profil.yml"
