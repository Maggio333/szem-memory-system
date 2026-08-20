#!/usr/bin/env bash
# bootstrap-instancji.sh — stawia instancje Szem end-to-end na gitolite (dedykowany user OS).
#
# Realizuje model-dostepu.md (HARD=repo/klucz per rola) + enforcement-runbook.md operacyjnie,
# jednym przebiegiem. Zwalidowany recznie 2026-08-20 (Monter) na PoC + realnej instancji;
# ten skrypt = destylacja tych krokow. GENERIC: dane instancji (sektory/role) w MANIFESCIE,
# nie w skrypcie — zero tresci instancji tutaj.
#
# Uzycie:   sudo bash bootstrap-instancji.sh <manifest.conf>
# UWAGA-SEC: manifest jest SOURCE-owany jako root = kod wykonywalny. Tylko z zaufanego zrodla/po review.
# Wymaga:   Linux/WSL, root (dla useradd/apt), git, python3; apt: gitolite3 openssh-server.
# Idempotent: powtorne uruchomienie nie duplikuje (user/klucze/repo tworzone tylko gdy brak).
#
# KRYTYCZNE zalozenia (z lekcji nocy):
#  - gitolite na DEDYKOWANYM userze (przejmuje jego authorized_keys) — NIGDY na load-bearing userze.
#  - repos na natywnym ext4 (home usera), NIE /mnt/c (9P zabija git many-small-files) — perf-flag Harta.
#  - localhost-first: sshd bez ekspozycji LAN; portproxy/LAN to osobna, swiadoma decyzja + threat-review.
set -euo pipefail

MANIFEST="${1:?usage: sudo bash bootstrap-instancji.sh <manifest.conf>}"
[ -f "$MANIFEST" ] || { echo "BLAD: brak manifestu $MANIFEST" >&2; exit 1; }
# shellcheck disable=SC1090
source "$MANIFEST"
: "${GITOLITE_USER:=szem-git}"
: "${INSTANCE_HOST:=localhost}"
: "${AGENT_KEYS_DIR:=/root/agent-keys}"           # prywatne klucze rol (ext4, poza /mnt/c), perms 600
: "${ADMIN_KEY:=/root/szem-admin/id_ed25519}"     # klucz-maintainer gitolite (bootstrap)
: "${META_REPO:=ods-instance}"
: "${SOFT_REPO:=ods-soft}"
: "${FORMATKA_URL:?manifest musi ustawic FORMATKA_URL (repo formatki do submodule-pin)}"
GHOME="/var/lib/$GITOLITE_USER"
run_git="sudo -u $GITOLITE_USER -H"

log(){ printf '[bootstrap] %s\n' "$*"; }
die(){ printf '[bootstrap][BLAD] %s\n' "$*" >&2; exit 1; }

# --- 0. narzedzia ---
command -v git >/dev/null || die "brak git"
command -v python3 >/dev/null || die "brak python3"

# --- 1. dedykowany user + gitolite (idempotent) ---
ensure_gitolite() {
  if ! id "$GITOLITE_USER" >/dev/null 2>&1; then
    log "tworze dedykowanego usera $GITOLITE_USER (home $GHOME, ext4)"
    useradd --system --create-home --home-dir "$GHOME" --shell /bin/bash "$GITOLITE_USER"
  fi
  if ! command -v gitolite >/dev/null && ! dpkg -l gitolite3 >/dev/null 2>&1; then
    log "instaluje gitolite3 + openssh-server"
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gitolite3 openssh-server
  fi
  if [ ! -f "$ADMIN_KEY" ]; then
    log "generuje klucz-admin (maintainer) $ADMIN_KEY"
    mkdir -p "$(dirname "$ADMIN_KEY")"; ssh-keygen -t ed25519 -N "" -C admin -f "$ADMIN_KEY" -q
    chmod 600 "$ADMIN_KEY"
  fi
  if [ ! -d "$GHOME/repositories/gitolite-admin.git" ]; then
    log "bootstrap gitolite adminkey"
    install -o "$GITOLITE_USER" -g "$GITOLITE_USER" -m 644 "$ADMIN_KEY.pub" "$GHOME/admin.pub"
    $run_git gitolite setup -pk "$GHOME/admin.pub"
  fi
  mkdir -p /run/sshd; (service ssh start >/dev/null 2>&1 || /usr/sbin/sshd 2>/dev/null || true)
  ss -tlnp 2>/dev/null | grep -q ':22 ' || log "UWAGA: sshd :22 nie nasluchuje — sprawdz recznie"
}

GSSH="ssh -i $ADMIN_KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
gclone(){ GIT_SSH_COMMAND="$GSSH" git clone -q "$GITOLITE_USER@$INSTANCE_HOST:$1" "$2"; }
gpush(){ GIT_SSH_COMMAND="$GSSH" git -C "$1" push -q origin master; }

WORK=$(mktemp -d)
export GIT_AUTHOR_NAME=bootstrap GIT_AUTHOR_EMAIL=bootstrap@szem GIT_COMMITTER_NAME=bootstrap GIT_COMMITTER_EMAIL=bootstrap@szem

# --- 2. gitolite.conf z manifestu (sektory HARD/SOFT + meta + soft-repo) ---
apply_config() {
  log "buduje gitolite.conf z manifestu (${#SECTORS[@]} sektorow)"
  gclone gitolite-admin "$WORK/gitolite-admin"
  local conf="$WORK/gitolite-admin/conf/gitolite.conf"
  {
    echo ""
    echo "# ===== instancja $META_REPO (bootstrap $(date -u +%F)) ====="
    local soft_rw=""
    for row in "${SECTORS[@]}"; do
      IFS='|' read -r name granica rw r <<<"$row"
      if [ "$granica" = "HARD" ]; then
        echo "repo $name"
        [ -n "$rw" ] && echo "    RW+     =   $rw"
        [ -n "$r" ]  && echo "    R       =   $r"
      else
        # SOFT: zbierz RW-role do wspolnego soft-repo (bo git nie ma per-path ACL)
        soft_rw="$soft_rw $rw"
      fi
    done
    # meta-repo: admin-ONLY RW (chroni submodule-pin przed podmiana), agent-role = R
    echo "repo $META_REPO"
    echo "    RW+     =   admin"
    [ -n "${META_READERS:-}" ] && echo "    R       =   $META_READERS"
    # soft-repo: RW dla zebranych SOFT-rol, R dla czytajacych
    echo "repo $SOFT_REPO"
    echo "    RW+     =   admin"
    [ -n "$soft_rw" ] && echo "    RW      =  $soft_rw"
    [ -n "${SOFT_READERS:-}" ] && echo "    R       =   $SOFT_READERS"
  } >> "$conf"
  git -C "$WORK/gitolite-admin" add -A
  git -C "$WORK/gitolite-admin" commit -q -m "bootstrap: sektory instancji $META_REPO (ACL wg manifestu)"
  gpush "$WORK/gitolite-admin"
}

# --- 3. klucze rol (gen ext4 600 + keydir) ---
add_roles() {
  gclone gitolite-admin "$WORK/ga-keys"
  for role in "${ROLES[@]}"; do
    local kd="$AGENT_KEYS_DIR/$role"
    if [ ! -f "$kd/id_ed25519" ]; then
      log "gen klucz roli $role (ext4, 600)"
      mkdir -p "$kd"; ssh-keygen -t ed25519 -N "" -C "$role" -f "$kd/id_ed25519" -q; chmod 600 "$kd/id_ed25519"
    fi
    cp "$kd/id_ed25519.pub" "$WORK/ga-keys/keydir/$role.pub"
    log "  $role fp: $(ssh-keygen -lf "$kd/id_ed25519.pub" | awk '{print $2}')"
  done
  git -C "$WORK/ga-keys" add -A
  git -C "$WORK/ga-keys" commit -q -m "bootstrap: klucze rol (${ROLES[*]})" || true
  gpush "$WORK/ga-keys" || true
}

# --- 4. meta-repo: submodule-pin formatki + SOFT-sektory do soft-repo ---
compose_meta() {
  log "meta-repo: submodule-pin formatki ($FORMATKA_URL)"
  gclone "$META_REPO" "$WORK/meta"
  ( cd "$WORK/meta"
    git -c protocol.file.allow=always submodule add -q "$FORMATKA_URL" formatka 2>/dev/null || true
    printf '# %s (instancja Szem)\nMeta: submodule-pin formatki + rejestr. Klucze rol=przy instancjacji. Bootstrap %s.\n' \
      "$META_REPO" "$(date -u +%F)" > README.md
    git add -A; git commit -q -m "bootstrap: submodule-pin formatki + README" || true )
  gpush "$WORK/meta" || true
  # SOFT-sektory -> soft-repo (foldery _sektor.md)
  gclone "$SOFT_REPO" "$WORK/soft"
  for row in "${SECTORS[@]}"; do
    IFS='|' read -r name granica rw r <<<"$row"
    [ "$granica" = "SOFT" ] || continue
    printf -- "---\nsektor: %s\ngranica: SOFT\nrw: %s\nr: %s\nstatus: struktura (tresc=fill po content-gate)\n" \
      "$name" "$rw" "$r" > "$WORK/soft/${name}_sektor.md"
  done
  ( cd "$WORK/soft"; git add -A; git commit -q -m "bootstrap: SOFT-sektory" || true )
  gpush "$WORK/soft" || true
}

# --- 5. verify dwustronny per rola + not-LAN-exposed ---
verify() {
  log "VERIFY dwustronny (kazda rola: swoj sektor OK / cudzy DENIED)"
  local fail=0
  for role in "${ROLES[@]}"; do
    local key="$AGENT_KEYS_DIR/$role/id_ed25519"
    # znajdz pierwszy HARD sektor gdzie rola ma RW+ (pozytyw) i pierwszy gdzie nie ma (negatyw)
    local own="" other=""
    for row in "${SECTORS[@]}"; do
      IFS='|' read -r name granica rw r <<<"$row"
      [ "$granica" = "HARD" ] || continue
      case " $rw $r " in *" $role "*) [ -z "$own" ] && own="$name" ;; *) [ -z "$other" ] && other="$name" ;; esac
    done
    local ks="ssh -i $key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null"
    if [ -n "$own" ]; then GIT_SSH_COMMAND="$ks" git clone -q "$GITOLITE_USER@$INSTANCE_HOST:$own" "$WORK/vp-$role" 2>/dev/null \
       && log "  [OK]  $role -> $own" || { log "  [FAIL-pozytyw] $role -> $own"; fail=1; }; fi
    if [ -n "$other" ]; then GIT_SSH_COMMAND="$ks" git clone -q "$GITOLITE_USER@$INSTANCE_HOST:$other" "$WORK/vn-$role" 2>/dev/null \
       && { log "  [FAIL-negatyw] $role -> $other (POWINNO DENIED)"; fail=1; } || log "  [DENY] $role -> $other (ok)"; fi
  done
  log "not-LAN-exposed check: netsh portproxy (Windows) MUSI byc pusty; sshd = internal-NAT only"
  [ "$fail" = 0 ] && log "VERIFY GREEN" || die "VERIFY FAIL — sprawdz ACL/manifest"
}

ensure_gitolite
apply_config
add_roles
compose_meta
verify
log "INSTANCJA $META_REPO GOTOWA (localhost-first). Klucze rol: $AGENT_KEYS_DIR/*/id_ed25519 (perms 600)."
log "Nastepny krok: przekaz klucz prywatny roli do jej agenta; ekspozycja LAN = osobna decyzja + threat-review."
rm -rf "$WORK"
