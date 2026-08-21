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
| 1 | **Tożsamość** | profil agenta: imię/rola/ID, sektory, granice; weryfikowalny przy starcie (profil-check — lekcja misfire) | `instancja/agenci/<imię>/profil.yml` + rejestr kluczy instancji; przy starcie sesji: przedstaw się i zweryfikuj z rejestrem |
| 2 | **Skills** | metoda + dziennik + protokoły (forum, restart, zamykanie) dostępne agentowi; osobno: skille instancji (per-projekt) | skills-mount: `skills/` formatki + skille instancji; konfiguracja ładuje oba zbiory |
| 3 | **Klucze sektorów** | dostęp do HARD sektorów per rola (RBAC repo/klucz); zero sekretów w gicie | ssh-config/git-remote per rola na klucz z katalogu kluczy (wskaźnik ścieżki, nigdy sam klucz) |
| 4 | **Tracker zadań** | wskaźnikowy, per agent; trzyma pointery do węzłów, nie kopie rozumowania | jedno bd per agent (decyzja operatora instancji) |
| 5 | **Kanał koordynacji** | meldunki, claimy, digest; watcher z relevance-gate | forum git-backed + watcher v2 (`WATCH_ROLE`/`WATCH_DOMAINS` per agent) |
| 6 | **Cykl życia** | restart/ciągłość: odzysk z trackera→dziennik→kanał; zamykanie: utrwal→PARKED; spory tożsamości: operator = kotwica | protokoły w skills/ (restart, zamykanie) — skodyfikowane jako skille formatki |

> Zasada: **substrat nie zna adaptera, adapter zna substrat.** Formatka nigdy nie importuje konfiguracji harnessu; adapter importuje formatkę (submodule, pin-sha).

## 3. Adapter-Omp — pierwsza implementacja (nasz harness)

Omp (oh-my-pi) jako domyślny system agentyczny. Konfiguracja per agent w **instancji** (nie w formatce — instancja to prywatny byt):

```
instancja/
├── formatka/            # submodule (pin-sha) — substrat, nie ruszany przez adapter
├── agenci/
│   └── <agent_slug>/   # per-agent config:
│       ├── profil.yml   #   tożsamość: rola, sektory, granice (wskaźniki)
│       ├── tozsamosc/   #   mandat, granice i dziennik agenta
│       │   ├── o-mnie.md
│       │   └── dziennik.md
│       ├── skills/      #   skills-mount: -> formatka/skills + instancja/skille
│       ├── .beads/      #   lokalny tracker z trzema neutralnymi zadaniami pierwszego dyżuru
│       ├── ssh-config   #   klucz roli: Host gitolite → IdentityFile <ścieżka klucza>
│       └── watcher.env  #   WATCH_ROLE/WATCH_DOMAINS (kanał koordynacji)
└── rejestr-kluczy.md    # role → fingerprint (kotwica integralności)

- **Odpalenie agenta:** `omp` z profilem → wstaje tożsamość + skills + klucze + tracker; sektory dostępne przez git-remote na kluczu roli.
- **Budowa workspace agenta (strona klienta):** `tools/workspace-builder.sh <manifest> <agent_slug> <agent_id> <rola>` tworzy `agenci/<agent_slug>/` (profil.yml, skills-mount, `.beads/`, ssh-config, watcher.env) + klonuje sektory dostępne dla roli na jej kluczu + verify-pozytyw. `agent_slug` jest walidowany przed utworzeniem katalogu; `agent_id` jest prywatnym identyfikatorem w profilu/tożsamości. Windows: `tools/start.bat agent <manifest> <agent_slug> <agent_id> <rola>` (auto-routing do WSL — zamyka gap#5).
- **Tracker:** workspace-builder tworzy lokalny, bezremote’owy Git-root workspace (`.git/`), którego Beads wymaga do własnego `.beads/`; oba pozostają runtime-only. Następnie uruchamia `bd init --non-interactive --init-if-missing --prefix <agent_id> --stealth` z katalogu workspace, a każde `show`/`create` uruchamia z tego samego katalogu — tracker pozostaje lokalny w `<workspace>/.beads`. Seeduje trzy lokalne beady pierwszego dyżuru: profil-check, przeczytanie metody+dziennika oraz potwierdzenie mandatu/granic z wyborem bezpiecznego zakresu. Seed ma deterministyczne lokalne ID `<agent_id>-<seed>`; przed `create` builder sprawdza je przez `bd show`, więc retry po awarii między trwałym create a markerem nie tworzy duplikatu. Osobny marker każdego seeda w `.beads/` skraca kolejne re-run. Pierwszy prywatny wpis dziennika opisuje ten sam neutralny następny krok bez nierozwiązanych placeholderów. Tracker nie wchodzi do publicznego repo; przechowuje pointery do węzłów, nie kopie rozumowania.
- **Wzorzec tożsamości:** publiczne `templates/agenta/` daje neutralne profile/dziennik; private `agent_id` jest renderowany lokalnie i nie należy do publicznej formatki.
- **Zero sekretów w gicie:** klucze żyją poza repo (katalog kluczy, perms 600); w gicie tylko wskaźnik ścieżki i fingerprint. `.beads/` nie jest materiałem do commitowania ani synchronizacji repo.
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
- Kanał koordynacji (posty, watcher, checkin/wake): `docs/kanal-koordynacji.md`
- Metoda i higiena: `skills/metoda.md`, `skills/dziennik.md`
- Instancja (drzewo, meta/HARD/SOFT): `templates/struktura-instancji.md`
- Bootstrap (serwer: gitolite/sektory/klucze): `tools/bootstrap-instancji.sh`; workspace agenta (klient): `tools/workspace-builder.sh`; Windows-entry (auto-WSL): `tools/start.bat`
