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
if [ "${1:-}" = "--version" ]; then echo "bd test"; exit 0; fi
if [ "${1:-}" = "init" ]; then
  mkdir -p "$BEADS_DIR"
  touch "$BEADS_DIR/initialized"
  printf '%s\n' "$*" > "$BEADS_DIR/bd-args"
  exit 0
fi
if [ "${1:-}" = "create" ]; then
  printf '%s\n' "$*" >> "$BEADS_DIR/create-args"
  touch "$BEADS_DIR/seed-task"
  exit 0
fi
exit 1
EOF

cat > "$tmp/bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "clone" ]; then
  destination="${!#}"
  mkdir -p "$destination/.git"
  exit 0
fi
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
  PATH="$tmp/bin:$PATH" BEADS_BIN=bd bash "$ROOT/tools/workspace-builder.sh" "$tmp/manifest.conf" "$@"
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
mapfile -t seed_calls < "$workspace/.beads/create-args"
[ "${#seed_calls[@]}" -eq 3 ]
seed_content="$(printf '%s\n' "${seed_calls[@]}")"
case "$seed_content" in *'Pierwsza sesja: profil-check'*'Pierwsza sesja: przeczytaj metodę i dziennik'*'Pierwsza sesja: potwierdź mandat i wybierz zakres'*) ;; *) exit 1;; esac

printf 'PRYWATNY-WPIS\n' >> "$workspace/tozsamosc/dziennik.md"
build agent-alpha agent-001 rola-alpha
case "$(<"$workspace/tozsamosc/dziennik.md")" in *PRYWATNY-WPIS*) ;; *) exit 1;; esac
mapfile -t seed_calls < "$workspace/.beads/create-args"
[ "${#seed_calls[@]}" -eq 3 ]

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
