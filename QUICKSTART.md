# Szem — Quickstart

Od `git clone` do działającej instancji Szem z jednym agentem, w 6 krokach.
Wszystko poniżej to **wzorzec** (zero tresci instancji) — dane bierzesz z własnego manifestu.

> **GDZIE URUCHAMIAĆ:** narzędzia (`bootstrap-instancji.sh`, `workspace-builder.sh`)
> działają **tylko w WSL/Linux**. Na Windows odpalaj przez `tools\start.bat` — routuje do WSL.
> **NIE** uruchamiaj toolów z git-bash na Windows (bash→WSL-relay pada: `/bin/bash not found`).

## Wymagania

- **Windows + WSL** (zalecane Ubuntu 24.04) **lub** natywny Linux.
- W WSL/Linux: `git`, `python3`.
- **System agentyczny (harness)** — domyślnie **Omp (oh-my-pi)**: `omp --version` musi działać (instalacja wg dokumentacji projektu Omp; jeśli brak — zainstaluj najpierw, zanim przejdziesz do kroku 5).
- **Tracker zadań** — domyślnie **beads**: `bd --version` musi działać (analogicznie — instalacja wg dokumentacji; tracker jest wskaźnikowy, każdy agent ma własne).
- Do kroku 3 (`setup`, jednorazowo): **root** — `gitolite3` + `openssh-server` instalują się same (`apt`).
- Domyślna dystrybucja WSL bez `sudo`/`apt`? Ustaw `SZEM_WSL_DISTRO=Ubuntu-24.04` (widzi je `start.bat`).

## Mapa repo (formatka)

| Katalog | Co zawiera |
|---|---|
| `docs/` | Mechanika: model dostępu, sector-contract, ontologia węzłów, enforcement-runbook |
| `skills/` | Generyczna metoda + dziennik pracy (odinstancjonowane) |
| `templates/` | Szablony: `wezly/*` (typy węzłów), sektor-README, matryca-RBAC, struktura-instancji |
| `tools/` | `bootstrap-instancji.sh` (serwer), `workspace-builder.sh` (klient), `start.bat` (Windows-entry), `forum-watch.sh` (watcher), `instance-manifest.example.conf` |

## Kroki

### 1. Sklonuj formatkę

```
git clone <URL-Twojego-szem.git> szem
cd szem
```

### 2. Przygotuj manifest (POZA publiczną formatką)

```
cp tools/instance-manifest.example.conf ../moja-instancja.conf
```

Wypełnij w `moja-instancja.conf`:
- `FORMATKA_URL` — ścieżka/URL do Twojego `szem.git` (to samo źródło co w kroku 1),
- `ROLES` — role Twojej instancji (np. `perf infra deploy`),
- `SECTORS` — wiersze `nazwa|HARD/SOFT|role-RW|role-R`,
- `META_READERS` — kto czyta meta-repo,
- `AGENT_KEYS_DIR` — gdzie lądują klucze ról (domyślnie `/srv/szem/agent-keys`); **musi być czytelny dla usera uruchamiającego `workspace-builder`** — NIE `/root` (perms 700 → nie-root nie odczyta),
- `AGENT_OS_USER` — user OS uruchamiający agentów/`workspace-builder` (nie-root): bootstrap **chownuje** mu klucze. Puste = agent jako root (WSL-default).

Manifest jest **parsowany** bezpiecznym whitelist-parserem (`tools/lib-manifest.sh` — nie wykonywany jako kod) — ale i tak trzymaj w zaufanym miejscu, **nigdy** w publicznym repo (niesie nazwy ról/sektorów).

### 3. Postaw instancję (serwer: gitolite + sektory + klucze ról)

- **Windows:** `tools\start.bat setup ..\moja-instancja.conf`
- **Linux/WSL:** `sudo bash tools/bootstrap-instancji.sh ../moja-instancja.conf`

✅ **Sukces:** w logu
```
[VERIFY dwustronny ...]  [OK] <rola> -> <własny-sektor>   [DENY] <rola> -> <cudzy> (ok)
INSTANCJA <META_REPO> GOTOWA (localhost-first). Klucze rol: <AGENT_KEYS_DIR>/*/id_ed25519 (perms 600).
```
Każda rola klonuje SWÓJ sektor (`[OK]`), cudzy jest odmówiony (`[DENY]`) — to jest hard-RBAC działający.

### 3b. Zaczep INSTANCE_DIR — submodule formatki

Zanim zbudujesz agenta, utwórz katalog instancji (`INSTANCE_DIR` z manifestu) z **submodule formatki** — inaczej `workspace-builder` zbuduje agenta, ale `skills/` będzie **pusty** (ostrzeże: `UWAGA: brak instancja/formatka/skills`). Wzorzec (`templates/struktura-instancji.md` → „Minimalna instancja"):

```
mkdir -p instancja && cd instancja
git -c protocol.file.allow=always submodule add <FORMATKA_URL> formatka   # pin-sha, nie branch; flaga tylko dla file://
cd ..
```

Meta-repo instancji (README + `rejestr-kluczy.md` + pin formatki) = RW tylko admin; agent-role = R (pin formatki niepisywalny przez agenta).

### 4. Zbuduj workspace agenta (klient: profil + dostęp + watcher)

- **Windows:** `tools\start.bat agent ..\moja-instancja.conf <imię> <rola>`
- **Linux/WSL:** `bash tools/workspace-builder.sh ../moja-instancja.conf <imię> <rola>`

`<rola>` musi być jedną z `ROLES` manifestu (mapuje na klucz roli i dostęp do sektorów).
**Nie-root:** jeśli `workspace-builder` uruchamia user-agenta (nie root), ustaw w manifeście `AGENT_OS_USER=<ten-user>` (bootstrap chownuje mu klucze) + `AGENT_KEYS_DIR` poza `/root`. Jako root (WSL-default) — `AGENT_OS_USER` puste. Idempotentne (istniejący klon = pomija).

✅ **Sukces:** `WORKSPACE <imię> GOTOWY: instancja/agenci/<imię>`

Powstaje `instancja/agenci/<imię>/`:
- `profil.yml` — tożsamość (wskaźniki, nigdy sekrety),
- `ssh-config` — remote git na kluczu roli,
- `watcher.env` — `WATCH_ROLE` + `WATCH_DOMAINS` dla tej roli,
- `skills/` — mount `formatka/skills` + skille instancji,
- sklonowane sektory dostępne dla roli.

### 5. Uruchom agenta (adapter-Omp)

```
. instancja/agenci/<imię>/watcher.env
export GIT_SSH_COMMAND="ssh -F instancja/agenci/<imię>/ssh-config"
omp --profile=<imię> --cwd=instancja/agenci/<imię> --append-system-prompt=instancja/agenci/<imię>/profil.yml
```

Przy starcie sesji: **profil-check** — agent przedstawia się i weryfikuje wg `rejestr-kluczy.md`
(kanoniczność = operator faktycznie prowadzący sesję).

### 5b. Wielu agentów naraz (multi-agent)

Wzorzec: **jeden pane = jeden agent = jeden workspace**. Krok 4 raz per agenta (`<imię> <rola>` z `ROLES`), potem w każdym panelu (split cmd / tmux) krok 5 z workspace'em tego agenta.

Goły `omp` ×N dzieli JEDEN profil konta OS (`~/.omp/agent/`: auth, sesje, cache) → kolizje. Izolacja per-agent = **`--profile=<imię>`** (relokuje bazę do `~/.omp/profiles/<imię>/agent/` — auth/sesje/ustawienia/stan osobne):

```
# pane 1:
omp --profile=A --cwd=instancja/agenci/A --append-system-prompt=instancja/agenci/A/profil.yml
# pane 2 (analogicznie 3, 4, ...):
omp --profile=B --cwd=instancja/agenci/B --append-system-prompt=instancja/agenci/B/profil.yml
```

Izolację **sektorów** między panelami egzekwuje gitolite (klucz roli w `ssh-config`/`GIT_SSH_COMMAND`), nie terminal: agent A nie sklonuje sektorów agenta B (`[DENY]`), nawet na tej samej maszynie. **Nie współdziel working copy między agentami** (race na checkout/branch) — wspólne są tylko remote'y (gitolite) i kanał koordynacji.

### 6. Klucz prywatny roli

Zostaje na maszynie agenta (perms 600), **nigdy** commitowany.
Rewokacja dostępu = usunięcie klucza roli z gitolite (O(1), bez rewritu historii).

## Co dalej

- Wypełnianie sektorów węzłami: `templates/wezly/*` + `docs/sector-contract.md` + `templates/struktura-instancji.md`.
- Ekspozycja instancji w LAN = osobna, świadoma decyzja + threat-review. Domyślnie **localhost-first**.
