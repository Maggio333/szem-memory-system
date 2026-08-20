# Szem — Quickstart

Od `git clone` do działającej instancji Szem z jednym agentem, w 6 krokach.
Wszystko poniżej to **wzorzec** (zero tresci instancji) — dane bierzesz z własnego manifestu.

> **GDZIE URUCHAMIAĆ:** narzędzia (`bootstrap-instancji.sh`, `workspace-builder.sh`)
> działają **tylko w WSL/Linux**. Na Windows odpalaj przez `tools\start.bat` — routuje do WSL.
> **NIE** uruchamiaj toolów z git-bash na Windows (bash→WSL-relay pada: `/bin/bash not found`).

## Wymagania

- **Windows + WSL** (zalecane Ubuntu 24.04) **lub** natywny Linux.
- W WSL/Linux: `git`, `python3`.
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
- `META_READERS` — kto czyta meta-repo.

Manifest jest source-owany jako **root** — trzymaj w zaufanym miejscu, **nigdy** w publicznym repo.

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
Nie-root; idempotentne (istniejący klon = pomija).

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
GIT_SSH_COMMAND="ssh -F instancja/agenci/<imię>/ssh-config"
# odpal harness z profilem: instancja/agenci/<imię>/profil.yml
```

Przy starcie sesji: **profil-check** — agent przedstawia się i weryfikuje wg `rejestr-kluczy.md`
(kanoniczność = operator faktycznie prowadzący sesję).

### 6. Klucz prywatny roli

Zostaje na maszynie agenta (perms 600), **nigdy** commitowany.
Rewokacja dostępu = usunięcie klucza roli z gitolite (O(1), bez rewritu historii).

## Co dalej

- Wypełnianie sektorów węzłami: `templates/wezly/*` + `docs/sector-contract.md` + `templates/struktura-instancji.md`.
- Ekspozycja instancji w LAN = osobna, świadoma decyzja + threat-review. Domyślnie **localhost-first**.
