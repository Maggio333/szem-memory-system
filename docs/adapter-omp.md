# Adapter — warstwa między formatką a systemem agentycznym

> **Dlaczego adapter.** Formatka Szem jest substratem pod DOWOLNY system agentyczny (model dostępu, węzły, metoda — zero zależności od konkretnego harnessu). Przepinanie systemów (wybór i zmiana) to nie przebudowa substratu — to wymiana **warstwy adaptera**. Ten dokument definiuje kontrakt, który każdy adapter MUSI spełnić, oraz pierwszą implementację: **Adapter-Omp**.

## 1. Granice (co jest czym)

| Warstwa | Zawiera | Zależy od |
|---|---|---|
| **Substrat (formatka)** | docs/, templates/, skills/ (metoda), tools/ — węzły, sektory, RBAC, dialektyka | niczego (harness-agnostic) |
| **Adapter** | dostarczenie agenta: tożsamość, skills-mount, klucze sektorów, tracker, kanał koordynacji | konkretny harness |
| **Instancja** | prywatne repo, sektory z treścią, klucze ról, konfiguracja per agent | substrat + adapter |

## 2. Kontrakt adaptera — co MUSI dostarczyć agentowi Szem

| # | Wymaganie | Opis | Adapter-Omp (implementacja) |
|---|---|---|---|
| 1 | **Tożsamość** | profil agenta: imię/rola/ID, sektory, granice; weryfikowalny przy starcie (profil-check — lekcja misfire) | `agents.git/<imie>/` (o-mnie.md + dziennik.md) + rejestr kluczy instancji; przy starcie sesji: przedstaw się i zweryfikuj z rejestrem |
| 2 | **Skills** | metoda + dziennik + protokoły (forum, restart, zamykanie) dostępne agentowi; osobno: skille instancji (per-projekt) | skills-mount: `skills/` formatki + skille instancji; konfiguracja ładuje oba zbiory |
| 3 | **Klucze sektorów** | dostęp do HARD sektorów per rola (RBAC repo/klucz); zero sekretów w gicie | ssh-config/git-remote per rola na klucz z katalogu kluczy (wskaźnik ścieżki, nigdy sam klucz) |
| 4 | **Tracker zadań** | wskaźnikowy, per agent; trzyma pointery do węzłów, nie kopie rozumowania | jedno bd per agent (decyzja Arka) |
| 5 | **Kanał koordynacji** | meldunki, claimy, digest; watcher z relevance-gate | forum git-backed + watcher v2 (`WATCH_ROLE`/`WATCH_DOMAINS` per agent) |
| 6 | **Cykl życia** | restart/ciągłość: odzysk z trackera→dziennik→kanał; zamykanie: utrwal→PARKED; spory tożsamości: operator = kotwica | protokoły w skills/ (restart, zamykanie) — skodyfikowane jako skille formatki |

> Zasada: **substrat nie zna adaptera, adapter zna substrat.** Formatka nigdy nie importuje konfiguracji harnessu; adapter importuje formatkę (submodule, pin-sha).

## 3. Adapter-Omp — pierwsza implementacja (nasz harness)

Omp (oh-my-pi) jako domyślny system agentyczny. Konfiguracja per agent w **instancji** (nie w formatce — instancja to prywatny byt):

```
instancja/
├── formatka/            # submodule (pin-sha) — substrat, nie ruszany przez adapter
├── agenci/
│   └── <imie>/          # per-agent config:
│       ├── profil.yml   #   tożsamość: rola, sektory, granice (wskaźniki)
│       ├── skills/      #   skills-mount: -> formatka/skills + instancja/skille
│       ├── ssh-config   #   klucz roli: Host gitolite → IdentityFile <ścieżka klucza>
│       └── watcher.env  #   WATCH_ROLE/WATCH_DOMAINS (kanal koordynacji)
└── rejestr-kluczy.md    # role → fingerprint (kotwica integralności)
```

- **Odpalenie agenta:** `omp` z profilem → wstaje tożsamość + skills + klucze + tracker; sektory dostępne przez git-remote na kluczu roli.
- **Zero sekretów w gicie:** klucze żyją poza repo (katalog kluczy, perms 600); w gicie tylko wskaźnik ścieżki i fingerprint.
- **Attribution:** README formatki podaje podstawę na Omp (uczciwe źródło) — patrz README §Podstawa.

## 4. Jak dodać drugi adapter (np. inny harness)

1. Spełnij kontrakt §2 (wszystkie 6 wymagań) na swoim harnessie.
2. Opisz implementację jako `docs/adapter-<nazwa>.md` (ta sama tabela).
3. Instancja wybiera adapter per agent; substrat bez zmian.

## 5. Granice i anty-wzorce

- **Nie** wciągaj logiki harnessu do formatki (węzły/sektory/metoda nie znają Ompa).
- **Nie** trzymaj kluczy/tokenów w repo adaptera — tylko wskaźniki.
- **Nie** duplikuj protokołów (restart/zamykanie) w adapterze — są w skills/ formatki, adapter je montuje.
- Adapter bez kontraktu §2 = niekompletny: agent dostaje narzędzia, ale nie ciągłość/tożsamość.

## Powiązania

- Warstwa dostępu (repo/klucz per rola): `docs/model-dostepu.md`, `templates/matryca-rbac.md`
- Metoda i higiena: `skills/metoda.md`, `skills/dziennik.md`
- Instancja (drzewo, meta/HARD/SOFT): `templates/struktura-instancji.md`
- Bootstrap: `tools/bootstrap-instancji.sh`
