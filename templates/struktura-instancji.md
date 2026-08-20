# Struktura instancji Szem

> Jak zbudować instancję z formatki (sklonuj-i-wypelniaj). Instancja = prywatny byt, który IMPORTUJE formatkę (submodule, pin-sha) i żyje na własnych repo/kluczach. Wszystko poniżej to wzorzec, nie treść.

## Drzewo instancji

```
instancja/
├── README.md                  # co to za instancja, kto ma dostęp, status
├── formatka/                  # submodule: import formatki (pin-sha, nie branch!)
│   └── (docs/, templates/, skills/, tools/ z formatki)
├── rejestr-kluczy.md          # role -> fingerprint kluczy (kotwica integralności)
├── sektory-soft/              # miękkie sektory (wspólny repo, foldery)
│   └── <sektor>/_sektor.md    # index sektora (węzły)
├── <sektor-hard>/             # HARD sektor = OSOBNE repo/klucz per rola
│   ├── _sektor.md             # frontmatter: wrazliwość, role, granica, zależności
│   ├── wezly/                 # typowane węzły (templates/wezly/*)
│   │   ├── PROJ-C1-cel.md
│   │   ├── PROJ-T1-teza.md
│   │   └── ...
│   └── README.md
└── tools/                     # watcher, bootstrap, ledger-generator (z formatki tools/)
```

## Reguły
- **Meta-repo** (README + rejestr-kluczy + submodule formatka): RW tylko admin/instance-maintainer. **Agent-role = R-only** (pin formatki niepisywalny przez agentów — finding F-ACL-2).
- **HARD sektor = osobne repo + osobny klucz roli** (git nie ma per-path ACL). Właściciel = RW+, czytający wg matrycy.
- **SOFT sektor** = foldery we wspólnym repo (miękka granica).
- **Sektor jako zbiór węzłów** — patrz `templates/sektor-repo-README.md` i `docs/sector-contract.md`.
- **Wrazliwość = kandydat od autora, werdykt = niezależny gate** (tag ≠ verdict).

## Cykl życia sektora
1. Autor: `_sektor.md` + węzły (tag wrazliwości: PUBLIC / PUBLIC-AFTER-SCRUB / PRIVATE; default-deny).
2. Gate (nie-autor): werdykt wrazliwości + zgodność z kontraktem.
3. HARD → osobne repo + klucz roli; SOFT → folder.
4. Agent wypełnia węzły wg ontologii; ewaluacja = żywy ledger.

## Minimalna instancja (quickstart-shape)
```
git clone <formatka> formatka
mkdir instancja && cd instancja
git submodule add <formatka-url> formatka      # + pin-sha (a5bd9133-style)
# sektory: wg sector-contract; klucze: wg rejestr-kluczy.md
# narzedzia: skopiuj z formatki tools/ (watcher, bootstrap)
```
> Szczegółowe kroki postawienia na gitolite: `tools/bootstrap-instancji.sh` (Wartownik pkt 3 / Monter) + quickstart (Hart pkt 4, test zrozumiałości).
