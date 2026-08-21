#!/usr/bin/env bash
# test-workspace-builder.sh — publiczny smoke adaptera-Omp: profil, lokalne Beads i bezpieczny slug.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/keys/rola-alpha"
printf test-key > "$tmp/keys/rola-alpha/id_ed25519"
chmod 600 "$tmp/keys/rola-alpha/id_ed25519"

cat > "$tmp/bin/bd" <<'EOF'
#!/usr/bin/env bash
BEADS_DIR="${BEADS_DIR:-$PWD/.beads}"
issue_id() {
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "--id" ]; then
      printf '%s\n' "$2"
      return 0
    fi
    shift
  done
  return 1
}
command="${1:-}"
shift || true
if [ "$command" = "--version" ]; then echo "bd test"; exit 0; fi
if [ "$command" = "init" ]; then
  mkdir -p "$BEADS_DIR"
  touch "$BEADS_DIR/initialized"
  printf '%s\n' "$*" > "$BEADS_DIR/bd-args"
  exit 0
fi
if [ "$command" = "show" ]; then
  id="$(issue_id "$@")"
  [ -f "$BEADS_DIR/issues/$id" ]
  exit
fi
if [ "$command" = "create" ]; then
  id="$(issue_id "$@")"
  mkdir -p "$BEADS_DIR/issues"
  [ ! -e "$BEADS_DIR/issues/$id" ] || exit 1
  touch "$BEADS_DIR/issues/$id" "$BEADS_DIR/seed-task"
  printf 'create %s\n' "$*" >> "$BEADS_DIR/create-args"
  if [ "${BD_FAIL_AFTER_CREATE_ONCE:-}" = 1 ] && [ ! -e "$BEADS_DIR/fault-fired" ]; then
    touch "$BEADS_DIR/fault-fired"
    kill -TERM "$PPID"
  fi
  exit 0
fi
exit 1
EOF

cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  init|clone)
    destination="${!#}"
    mkdir -p "$destination/.git"
    exit 0
    ;;
esac
exit 1
EOF
chmod +x "$tmp/bin/bd" "$tmp/bin/git"

cat > "$tmp/manifest.conf" <<EOF
GITOLITE_USER=szem-git
INSTANCE_HOST=localhost
AGENT_KEYS_DIR=$tmp/keys
INSTANCE_DIR=$tmp/instancja
ROLES=(rola-alpha)
SECTORS=("sektor-alpha|HARD|rola-alpha|")
EOF

build() {
  PATH="$tmp/bin:$PATH" BEADS_BIN=bd BD_FAIL_AFTER_CREATE_ONCE="${BD_FAIL_AFTER_CREATE_ONCE:-}" \
    bash "$ROOT/tools/workspace-builder.sh" "$tmp/manifest.conf" "$@"
}

build agent-alpha agent-001 rola-alpha
workspace="$tmp/instancja/agenci/agent-alpha"
for seed in profil-check metoda-dziennik mandat-zakres; do
  [ -f "$workspace/.beads/.szem-first-run-$seed" ]
done
[ -f "$workspace/.beads/seed-task" ]
[ -f "$workspace/tozsamosc/o-mnie.md" ]
case "$(<"$workspace/profil.yml")" in *'id: agent-001'*) ;; *) exit 1;; esac
case "$(<"$workspace/tozsamosc/o-mnie.md")" in *'{{'*) exit 1;; *'**ID:** agent-001'*) ;; *) exit 1;; esac
case "$(<"$workspace/tozsamosc/dziennik.md")" in *'{{'*) exit 1;; *'przejmij bead profil-check'*) ;; *) exit 1;; esac
watcher_env="$(<"$workspace/watcher.env")"
case "$watcher_env" in *'WATCH_ROLE=rola-alpha'*'WATCH_FULL=1'*) ;; *) exit 1;; esac
case "$watcher_env" in *WATCH_DOMAINS*) exit 1;; esac
mapfile -t seed_calls < "$workspace/.beads/create-args"
[ "${#seed_calls[@]}" -eq 3 ]
seed_content="$(printf '%s\n' "${seed_calls[@]}")"
case "$seed_content" in *'Pierwsza sesja: profil-check'*'Pierwsza sesja: przeczytaj metodę i dziennik'*'Pierwsza sesja: potwierdź mandat i wybierz zakres'*) ;; *) exit 1;; esac

printf 'PRYWATNY-WPIS\n' >> "$workspace/tozsamosc/dziennik.md"
build agent-alpha agent-001 rola-alpha
case "$(<"$workspace/tozsamosc/dziennik.md")" in *PRYWATNY-WPIS*) ;; *) exit 1;; esac
mapfile -t seed_calls < "$workspace/.beads/create-args"
[ "${#seed_calls[@]}" -eq 3 ]
if BD_FAIL_AFTER_CREATE_ONCE=1 build agent-retry agent-002 rola-alpha >/dev/null 2>&1; then
  echo "FAIL: fault-after-create should stop the first build" >&2
  exit 1
fi
retry_workspace="$tmp/instancja/agenci/agent-retry"
build agent-retry agent-002 rola-alpha
for seed in profil-check metoda-dziennik mandat-zakres; do
  [ -f "$retry_workspace/.beads/.szem-first-run-$seed" ]
  [ -f "$retry_workspace/.beads/issues/agent-002-$seed" ]
done
mapfile -t retry_calls < "$retry_workspace/.beads/create-args"
[ "${#retry_calls[@]}" -eq 3 ]

bad_slugs=('../escape' 'agent/path' $'agent\nnewline')
for bad_slug in "${bad_slugs[@]}"; do
  if build "$bad_slug" agent-001 rola-alpha >/dev/null 2>&1; then
    echo "FAIL: accepted invalid agent_slug" >&2
    exit 1
  fi
done
[ ! -e "$tmp/instancja/escape" ]
[ ! -e "$tmp/instancja/agenci/agent" ]

echo "WORKSPACE-BUILDER-TEST-OK"
