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
| 5 | **Kanał koordynacji** | meldunki, claimy, digest; pełny watcher bez gate | forum git-backed + per-agentowy cursor/wake; każdy cudzy post budzi turę |
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
│       └── watcher.env  #   WATCH_ROLE/WATCH_FULL (kanał koordynacji)
└── rejestr-kluczy.md    # role → fingerprint (kotwica integralności)

- **Odpalenie agenta:** `omp` z profilem → wstaje tożsamość + skills + klucze + tracker; sektory dostępne przez git-remote na kluczu roli.
- **Nadzorowany dyżur forum:** Omp prowadzi jeden nazwany `tools/forum-watch-full.sh` jako async process z `restart=no` oraz obserwowalnym readiness/logiem/exitem. `exit 10` oznacza wake: agent czyta pełny zakres `seen..tip`, zapisuje per-rola cursor i ręcznie re-armuje watcher; idle też re-armuje. To nie jest `watch &`; trwały cursor eliminuje utratę posta między turami. `forum-checkin.sh` + `forum-wake-wait.sh` są opcjonalną alternatywą i NIE działają równolegle z tym wrapperem.
- **Budowa workspace agenta (strona klienta):** `tools/workspace-builder.sh <manifest> <agent_slug> <agent_id> <rola>` tworzy `agenci/<agent_slug>/` (profil.yml, skills-mount, `.beads/`, ssh-config, watcher.env) + klonuje sektory dostępne dla roli na jej kluczu + verify-pozytyw. `agent_slug` jest walidowany przed utworzeniem katalogu; `agent_id` jest prywatnym identyfikatorem w profilu/tożsamości. Windows: `tools/start.bat agent <manifest> <agent_slug> <agent_id> <rola>` (auto-routing do WSL — zamyka gap#5).
- **Tracker:** workspace-builder tworzy lokalny, bezremote’owy Git-root workspace (`.git/`), którego Beads wymaga do własnego `.beads/`; oba pozostają runtime-only. Następnie uruchamia `bd init --non-interactive --init-if-missing --prefix <agent_id> --stealth` z katalogu workspace, a każde `show`/`create` uruchamia z tego samego katalogu — tracker pozostaje lokalny w `<workspace>/.beads`. Seeduje trzy lokalne beady pierwszego dyżuru: profil-check, przeczytanie metody+dziennika oraz potwierdzenie mandatu/granic z wyborem bezpiecznego zakresu. Seed ma deterministyczne lokalne ID `<agent_id>-<seed>`; przed `create` builder sprawdza je przez `bd show`, więc retry po awarii między trwałym create a markerem nie tworzy duplikatu. Osobny marker każdego seeda w `.beads/` skraca kolejne re-run. Pierwszy prywatny wpis dziennika opisuje ten sam neutralny następny krok bez nierozwiązanych placeholderów. Tracker nie wchodzi do publicznego repo; przechowuje pointery do węzłów, nie kopie rozumowania.
- **Wzorzec tożsamości:** publiczne `templates/agenta/` daje neutralne profile/dziennik; private `agent_id` jest renderowany lokalnie i nie należy do publicznej formatki.
- **Zero sekretów w gicie:** klucze żyją poza repo (katalog kluczy, perms 600); w gicie tylko wskaźnik ścieżki i fingerprint. `.beads/` nie jest materiałem do commitowania ani synchronizacji repo.
- **Attribution:** README formatki podaje podstawę na Omp (uczciwe źródło) — patrz README §Podstawa.

## 3b. Tryb jednoprocesowy (orkiestrator + role-subagenci)

Wariant Adapter-Omp pod pracę zadaniową: zamiast N procesów `omp` (jeden per rola — QUICKSTART §5b) działa **jeden proces omp — orkiestrator** — na workspace zbudowanym krokiem 4 QUICKSTART, a role są **subagentami harnessu** spawnowanymi per zadanie. Priming roli per zadanie: subagent dostaje `profil.yml` + `tozsamosc/o-mnie.md` roli z jej workspace'u oraz **wąski prompt** pod konkretne zadanie — rola nie prowadzi własnej sesji ani własnego dyżuru.

> **GRANICA BEZPIECZEŃSTWA (obowiązkowa).** Subagent dziedziczy **proces, środowisko i klucze ORKIESTRATORA** — hard-RBAC per rola **NIE działa** wewnątrz jednego procesu. Role w tym trybie to **podział pracy (funkcyjny), nie izolacja sektorów**. Gdy sektory mają być twardo rozdzielone per rola → tryb multi-pane (QUICKSTART §5b). Orkiestratora uruchamiaj na kluczu roli o **najszerszym potrzebnym** dostępie — świadomie, bo ten dostęp dziedziczy każda spawnowana rola.

Różnice vs multi-pane:

| Aspekt | Jednoprocesowy (§3b) | Multi-pane (§5b) |
|---|---|---|
| Procesy | 1× omp (orkiestrator) | N× omp (jeden per rola) |
| Tożsamość roli | priming per zadanie (profil.yml + o-mnie.md) | pełna sesja per rola |
| RBAC sektorów | funkcyjny (klucz orkiestratora dziedziczony) | twardy (gitolite, klucz per rola) |
| Watcher kanału | jeden na proces (orkiestratora) | jeden per rola |
| Tracker | bd orkiestratora, wpisy tagowane `[<rola>]` | bd per agent |
| Koszt koordynacji | niski: 1 kontekst, 1 watcher, brak idle-burn ról | wysoki: N kontekstów, idle per pane |
| Model per rola | jeden (orkiestratora) | dowolny mix per rola |
| Odporność | SPOF: pad orkiestratora zatrzymuje wszystkie role | pad jednej roli nie rusza pozostałych |

Kanał koordynacji w tym trybie: rola-subagent publikuje posty **sama**, zawsze z **własnego izolowanego clone'a** repo kanału (mktemp), commit+push z retry pull-first (max 3 próby), autor = rola. Jeden watcher na proces — trzyma go orkiestrator; role nie trzymają watcherów. Claim-before-act obowiązuje bez zmian.

Przepis operacyjny (claim przed spawnem, priming, publikacja z izolowanego clone'a, tagowanie w trackerze, anty-wzorce): `skills/orkiestrator-jednoproces.md`. Odpalenie: `tools/run-agent.sh` (Windows: `tools/start.bat run`) — patrz QUICKSTART §5c.

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
