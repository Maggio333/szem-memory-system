#!/usr/bin/env bash
# workspace-builder.sh — buduje WORKSPACE agenta Szem (strona KLIENTA adaptera-Omp).
#
# Realizuje adapter-omp.md §3: instancja/agenci/<imie>/ { profil.yml, skills/, ssh-config, watcher.env }
# + klonuje sektory dostepne dla roli (na kluczu roli) + verify-pozytyw. Komplementarne do
# bootstrap-instancji.sh (strona SERWERA: gitolite/sektory/klucze). GENERIC: dane z manifestu+argi.
#
# Uzycie:   bash workspace-builder.sh <manifest.conf> <imie-agenta> <rola>
#   <rola> MUSI byc jedna z ROLES manifestu (mapuje na klucz roli + dostep do sektorow).
# Wymaga:   Linux/WSL (klucze rol z bootstrapa zyja na ext4, perms 600), git, ssh. NIE root
#           (workspace-builder dziala na kluczu roli, nie systemowo). Windows: uzyj tools/start.bat.
# Idempotent: nadpisuje configi agenta, nie duplikuje klonow (istniejacy .git = pomija).
set -euo pipefail

# gap#5 (test zrozumialosci): z git-bash Windows bash routuje przez WSL-relay i pada. Twardy stop:
[ "$(uname -s)" = Linux ] || { echo "BLAD: uruchom w WSL/Linux (wpisz: wsl), NIE z git-bash Windows. Windows-entry: tools/start.bat." >&2; exit 1; }

MANIFEST="${1:?usage: bash workspace-builder.sh <manifest.conf> <imie> <rola>}"
AGENT="${2:?podaj imie agenta}"
ROLE="${3:?podaj role (jedna z ROLES manifestu)}"
[ -f "$MANIFEST" ] || { echo "BLAD: brak manifestu $MANIFEST" >&2; exit 1; }
# shellcheck disable=SC1090
. "$(cd "$(dirname "$0")" && pwd)/lib-manifest.sh"
load_manifest "$MANIFEST"
: "${GITOLITE_USER:=szem-git}"
: "${INSTANCE_HOST:=localhost}"
: "${AGENT_KEYS_DIR:=/srv/szem/agent-keys}"       # musi byc CZYTELNY dla usera agenta (nie /root(700)) - fix #2
: "${INSTANCE_DIR:=./instancja}"

log(){ printf '[workspace] %s\n' "$*"; }
die(){ printf '[workspace][BLAD] %s\n' "$*" >&2; exit 1; }
join_csv(){ local IFS=,; echo "$*"; }

# rola musi istniec w ROLES manifestu
case " ${ROLES[*]:-} " in *" $ROLE "*) : ;; *) die "rola '$ROLE' nie jest w ROLES manifestu (${ROLES[*]:-brak})";; esac

KEY="$AGENT_KEYS_DIR/$ROLE/id_ed25519"
[ -e "$KEY" ] || die "klucz roli niedostepny: $KEY (nie istnieje LUB parent nietraversowalny dla $(id -un) — np. /root(700)). Napraw: AGENT_KEYS_DIR czytelny dla usera agenta ALBO bootstrap z AGENT_OS_USER=$(id -un); jesli instancji nie ma — najpierw bootstrap-instancji.sh. - fix #2"
[ -r "$KEY" ] || die "klucz $KEY istnieje ale NIECZYTELNY dla $(id -un): ustaw AGENT_KEYS_DIR na katalog czytelny dla usera agenta, LUB w bootstrapie AGENT_OS_USER=$(id -un) (klucze w /root sa root-only) - fix #2"

WS="$INSTANCE_DIR/agenci/$AGENT"
mkdir -p "$WS/skills"
log "workspace: $WS (rola=$ROLE)"

# --- sektory HARD dostepne dla roli (RW+ = wlasny, R = tylko-odczyt) ---
own_hard=(); ro_hard=()
for row in "${SECTORS[@]:-}"; do
  IFS='|' read -r name granica rw r <<<"$row"
  [ "$granica" = HARD ] || continue
  case " $rw " in *" $ROLE "*) own_hard+=("$name"); continue;; esac
  case " $r "  in *" $ROLE "*) ro_hard+=("$name");; esac
done

# --- profil.yml (adapter-omp §2 wym.1 tozsamosc; wskazniki, NIGDY sekrety) ---
cat > "$WS/profil.yml" <<YML
# profil agenta (adapter-omp §2 wym.1). Przy starcie sesji: przedstaw sie i zweryfikuj z rejestr-kluczy.md (profil-check).
imie: $AGENT
rola: $ROLE
sektory_rw: [$(join_csv "${own_hard[@]:-}")]
sektory_ro: [$(join_csv "${ro_hard[@]:-}")]
klucz: $KEY            # WSKAZNIK sciezki do klucza roli, nigdy sam klucz w gicie
gitolite: $GITOLITE_USER@$INSTANCE_HOST
YML

# --- ssh-config (adapter-omp §2 wym.3: klucz roli jako wskaznik) ---
cat > "$WS/ssh-config" <<CFG
# git-remote na kluczu roli. Uzycie:
#   z katalogu tego agenta:  GIT_SSH_COMMAND="ssh -F ssh-config" git clone gitolite:<sektor>
Host gitolite
    HostName $INSTANCE_HOST
    User $GITOLITE_USER
    IdentityFile $KEY
    IdentitiesOnly yes
    StrictHostKeyChecking accept-new
    UserKnownHostsFile $WS/known_hosts
CFG

# --- watcher.env (adapter-omp §2 wym.5: kanal koordynacji per agent) ---
dom_var="WATCH_DOMAINS_${ROLE//-/_}"   # bash nie dopuszcza '-' w nazwie zmiennej -> mapuj na '_'
cat > "$WS/watcher.env" <<ENV
# source przed re-arm watchera:  . $WS/watcher.env ; sh <formatka>/tools/forum-watch.sh
export WATCH_ROLE=$ROLE
export WATCH_DOMAINS='${!dom_var:-}'
export WATCH_REMOTE=1
export WATCH_DEBOUNCE=20
export WATCH_INTERVAL=15
export WATCH_MAX=1450
ENV

# --- skills-mount (adapter-omp §2 wym.2: formatka/skills + skille instancji) ---
if [ -d "$INSTANCE_DIR/formatka/skills" ]; then
  ln -sfn ../../formatka/skills "$WS/skills/formatka"
  log "skills-mount: formatka/skills -> $WS/skills/formatka"
else
  log "UWAGA: brak $INSTANCE_DIR/formatka/skills — dodaj submodule formatki (patrz templates/struktura-instancji.md)"
fi
[ -d "$INSTANCE_DIR/skille" ] && { ln -sfn ../../skille "$WS/skills/instancja"; log "skills-mount: skille/ -> $WS/skills/instancja"; }

# --- klonuj sektory dostepne dla roli (na kluczu roli) ---
GSSH="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$WS/known_hosts -o BatchMode=yes -o ConnectTimeout=10"
clone_sector(){ GIT_SSH_COMMAND="$GSSH" git clone -q "$GITOLITE_USER@$INSTANCE_HOST:$1" "$WS/$1" 2>/dev/null; }
for s in "${own_hard[@]:-}" "${ro_hard[@]:-}"; do
  [ -n "$s" ] || continue
  if [ -d "$WS/$s/.git" ]; then log "  sektor $s: juz sklonowany"; continue; fi
  if clone_sector "$s"; then log "  sektor $s: sklonowany"; else log "  UWAGA: sektor $s nie sklonowany (ACL/offline?)"; fi
done

# --- verify-pozytyw: klucz roli faktycznie klonuje wlasny sektor ---
if [ "${#own_hard[@]}" -gt 0 ] && [ -d "$WS/${own_hard[0]}/.git" ]; then
  log "VERIFY: klucz roli klonuje wlasny sektor '${own_hard[0]}' — OK"
elif [ "${#own_hard[@]}" -eq 0 ]; then
  log "VERIFY: rola '$ROLE' nie ma HARD-RW sektora (tylko R/SOFT?) — sprawdz manifest jesli to blad"
else
  die "VERIFY-pozytyw FAIL: rola '$ROLE' NIE sklonowala wlasnego sektora '${own_hard[0]}' — sprawdz klucz/ACL/bootstrap"
fi

log "WORKSPACE $AGENT GOTOWY: $WS"
log "Start agenta (adapter-omp): . $WS/watcher.env ; GIT_SSH_COMMAND=\"ssh -F $WS/ssh-config\" ; odpal harness z profilem $WS/profil.yml"
