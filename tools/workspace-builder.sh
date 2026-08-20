#!/usr/bin/env bash
# workspace-builder.sh — buduje WORKSPACE agenta Szem (strona KLIENTA adaptera-Omp).
#
# Realizuje adapter-omp.md §3: instancja/agenci/<imie>/ { profil.yml, skills/, ssh-config, watcher.env }
# + klonuje sektory dostepne dla roli (na kluczu roli) + verify-pozytyw. Komplementarne do
# bootstrap-instancji.sh (strona SERWERA: gitolite/sektory/klucze). GENERIC: dane z manifestu+argi.
#
# Uzycie:   bash workspace-builder.sh <manifest.conf> <agent_slug> <agent_id> <rola>
#   <agent_slug> to bezpieczna nazwa katalogu/profilu; <agent_id> to prywatny stabilny identyfikator.
#   <rola> MUSI byc jedna z ROLES manifestu (mapuje na klucz roli + dostep do sektorow).
# Wymaga:   Linux/WSL (klucze rol z bootstrapa zyja na ext4, perms 600), git, ssh. NIE root
#           (workspace-builder dziala na kluczu roli, nie systemowo). Windows: uzyj tools/start.bat.
# Idempotent: nadpisuje configi agenta, nie duplikuje klonow (istniejacy .git = pomija).
set -euo pipefail

# gap#5 (test zrozumialosci): z git-bash Windows bash routuje przez WSL-relay i pada. Twardy stop:
[ "$(uname -s)" = Linux ] || { echo "BLAD: uruchom w WSL/Linux (wpisz: wsl), NIE z git-bash Windows. Windows-entry: tools/start.bat." >&2; exit 1; }

MANIFEST="${1:?usage: bash workspace-builder.sh <manifest.conf> <agent_slug> <agent_id> <rola>}"
AGENT="${2:?podaj agent_slug (A-Za-z0-9, _, -)}"
AGENT_ID="${3:?podaj prywatny agent_id}"
ROLE="${4:?podaj role (jedna z ROLES manifestu)}"
[ -f "$MANIFEST" ] || { echo "BLAD: brak manifestu $MANIFEST" >&2; exit 1; }
# shellcheck disable=SC1090
. "$(cd "$(dirname "$0")" && pwd)/lib-manifest.sh"
load_manifest "$MANIFEST"
: "${GITOLITE_USER:=szem-git}"
: "${INSTANCE_HOST:=localhost}"
: "${AGENT_KEYS_DIR:=/srv/szem/agent-keys}"       # musi byc CZYTELNY dla usera agenta (nie /root(700)) - fix #2
: "${INSTANCE_DIR:=./instancja}"
: "${BEADS_BIN:=bd}"                              # tracker operacyjny per agent (lokalny, nie repo)
log(){ printf '[workspace] %s\n' "$*"; }
die(){ printf '[workspace][BLAD] %s\n' "$*" >&2; exit 1; }
join_csv(){ local IFS=,; echo "$*"; }
case "$AGENT" in
  [A-Za-z0-9]*)
    [[ "$AGENT" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "agent_slug '$AGENT' musi pasowac do [A-Za-z0-9][A-Za-z0-9_-]*"
    ;;
  *) die "agent_slug '$AGENT' musi zaczynac sie od A-Za-z0-9" ;;
esac
[[ "$AGENT_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "agent_id musi pasowac do [A-Za-z0-9][A-Za-z0-9._-]*"

# rola musi istniec w ROLES manifestu
case " ${ROLES[*]:-} " in *" $ROLE "*) : ;; *) die "rola '$ROLE' nie jest w ROLES manifestu (${ROLES[*]:-brak})";; esac

KEY="$AGENT_KEYS_DIR/$ROLE/id_ed25519"
[ -e "$KEY" ] || die "klucz roli niedostepny: $KEY (nie istnieje LUB parent nietraversowalny dla $(id -un) — np. /root(700)). Napraw: AGENT_KEYS_DIR czytelny dla usera agenta ALBO bootstrap z AGENT_OS_USER=$(id -un); jesli instancji nie ma — najpierw bootstrap-instancji.sh. - fix #2"
[ -r "$KEY" ] || die "klucz $KEY istnieje ale NIECZYTELNY dla $(id -un): ustaw AGENT_KEYS_DIR na katalog czytelny dla usera agenta, LUB w bootstrapie AGENT_OS_USER=$(id -un) (klucze w /root sa root-only) - fix #2"

FORMATKA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
AGENT_TEMPLATE_DIR="$FORMATKA_DIR/templates/agenta"
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
render_template() {
  local file="$1" content
  [ -f "$AGENT_TEMPLATE_DIR/$file" ] || die "brak szablonu agenta: $AGENT_TEMPLATE_DIR/$file"
  content="$(<"$AGENT_TEMPLATE_DIR/$file")"
  content="${content//\{\{NAZWA_AGENTA\}\}/$AGENT}"
  content="${content//\{\{ID_AGENTA\}\}/$AGENT_ID}"
  content="${content//\{\{ROLA\}\}/$ROLE}"
  content="${content//\{\{DATA_UTC\}\}/$NOW_UTC}"
  content="${content//\{\{BEADY_LUB_BRAK\}\}/3 neutralne beady onboarding; nieprzejęte}"
  content="${content//\{\{GRANICE\}\}/uzupełnij mandat i granice z prywatnej instancji; nie ujawniaj sekretów}"
  content="${content//\{\{BLOKERY_LUB_BRAK\}\}/brak na starcie}"
  content="${content//\{\{NASTEPNY_KROK\}\}/przejmij bead profil-check przed pracą merytoryczną}"
  content="${content//\{\{WYNIK\}\}/nie rozpoczęto}"
  content="${content//\{\{WSKAZNIK_LUB_BRAK\}\}/profil.yml i lokalny tracker}"
  content="${content//\{\{ZAKRES_ODPOWIEDZIALNOSCI\}\}/uzupełnij przed pierwszą pracą z prywatnej instancji}"
  content="${content//\{\{OPERATOR_LUB_INSTANCJA\}\}/prywatna instancja}"
  printf '%s\n' "$content"
}
WS="$INSTANCE_DIR/agenci/$AGENT"
mkdir -p "$WS/skills" "$WS/tozsamosc"
if [ ! -e "$WS/.git" ]; then
  git init -q "$WS" || die "nie udalo sie utworzyc lokalnego Git workspace dla Beads: $WS"
fi

log "workspace: $WS (rola=$ROLE)"

# --- tracker (adapter-omp §2 wym.4): trzy neutralne seedy pierwszego dyżuru, poza publicznym repo ---
command -v "$BEADS_BIN" >/dev/null 2>&1 || die "brak Beads ($BEADS_BIN); zainstaluj bd przed budowa workspace"
"$BEADS_BIN" --version >/dev/null 2>&1 || die "Beads ($BEADS_BIN) jest niedostepny dla tego WSL/Linux; zainstaluj linuxowa wersje bd przed budowa workspace"
if ! (cd "$WS" && "$BEADS_BIN" init \
  --non-interactive --init-if-missing --prefix "$AGENT_ID" \
  --stealth --skip-agents --skip-hooks >/dev/null 2>&1); then
  die "nie udalo sie zainicjalizowac lokalnego Beads: $WS/.beads"
fi
log "tracker: Beads lokalny per agent -> $WS/.beads (pointery, nie vault)"
seed_bead() {
  local seed="$1" marker="$WS/.beads/.szem-first-run-$1" title="$2" description="$3"
  local seed_id="$AGENT_ID-$seed"
  [ -e "$marker" ] && return
  if (cd "$WS" && "$BEADS_BIN" show --id "$seed_id" >/dev/null 2>&1); then
    : > "$marker"
    return
  fi
  if ! (cd "$WS" && "$BEADS_BIN" create \
    --id "$seed_id" --title "$title" --description "$description" --type task --priority 2 --silent >/dev/null); then
    die "nie udalo sie utworzyc beada pierwszego dyzuru: $WS/.beads"
  fi
  : > "$marker"
}
seed_bead profil-check "Pierwsza sesja: profil-check" \
  "Sprawdź tożsamość z profil.yml oraz rolę, granice i dostępne sektory. Nie zaczynaj pracy merytorycznej przed potwierdzeniem."
seed_bead metoda-dziennik "Pierwsza sesja: przeczytaj metodę i dziennik" \
  "Przeczytaj zamontowaną metodę oraz dziennik pracy. Tracker wskazuje zadania; trwałe rozumowanie pozostaje w dokumentach."
seed_bead mandat-zakres "Pierwsza sesja: potwierdź mandat i wybierz zakres" \
  "Uzupełnij mandat i granice z prywatnej instancji, potwierdź dostępne sektory i wybierz pierwszy bezpieczny zakres."
log "tracker: trzy neutralne beady pierwszego dyżuru są gotowe"

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
id: $AGENT_ID
rola: $ROLE
sektory_rw: [$(join_csv "${own_hard[@]:-}")]
sektory_ro: [$(join_csv "${ro_hard[@]:-}")]
klucz: $KEY            # WSKAZNIK sciezki do klucza roli, nigdy sam klucz w gicie
gitolite: $GITOLITE_USER@$INSTANCE_HOST
tracker: beads
tozsamosc_dir: $WS/tozsamosc
dziennik: $WS/tozsamosc/dziennik.md
lifecycle_skill: $WS/skills/formatka/agent-lifecycle.md
tracker_dir: $WS/.beads
YML

# --- tozsamosc (publiczny wzorzec; prywatny stan nie jest nadpisywany przy kolejnym buildzie) ---
if [ ! -e "$WS/tozsamosc/o-mnie.md" ]; then
  render_template o-mnie.md > "$WS/tozsamosc/o-mnie.md"
fi
if [ ! -e "$WS/tozsamosc/dziennik.md" ]; then
  render_template dziennik.md > "$WS/tozsamosc/dziennik.md"
fi
log "tozsamosc: $WS/tozsamosc/{o-mnie.md,dziennik.md}"

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
log "Tracker: Beads lokalny per agent (nie commituj .beads/); start: bd --db $WS/.beads prime"
log "Identity: $WS/tozsamosc (uzupelnij mandat/granice przed pierwsza sesja)"
log "Start agenta (adapter-omp): . $WS/watcher.env ; GIT_SSH_COMMAND=\"ssh -F $WS/ssh-config\" ; odpal harness z profilem $WS/profil.yml"
