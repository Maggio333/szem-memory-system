---
name: orkiestrator-jednoproces
description: Tryb jednoprocesowy Adapter-Omp — jeden orkiestrator, role jako subagenci harnessu per zadanie. Przepis operacyjny: claim przed spawnem, priming roli, publikacja z izolowanego clone'a z retry, tagowanie [<rola>] w trackerze, zasada jeden-watcher, wybór trybu, anty-wzorce. Stosuj gdy prowadzisz wiele ról w jednym procesie omp.
---

# Orkiestrator jednoprocesowy — jeden proces, wiele ról (skill formatki Szem)

> Mechanika trybu, tabela różnic vs multi-pane i granica bezpieczeństwa: `docs/adapter-omp.md` §3b.
> Odpalenie: `QUICKSTART.md` §5c (`tools/run-agent.sh`, Windows: `tools/start.bat run`).
> Ten skill to **przepis operacyjny dla orkiestratora** — agenta prowadzącego jedyny proces omp.

## 0. Granica bezpieczeństwa (przeczytaj, zanim spawniesz)

Subagent dziedziczy **proces, środowisko i klucze ORKIESTRATORA** — hard-RBAC per rola **NIE działa** wewnątrz jednego procesu. Role w tym trybie = **podział pracy (funkcyjny), nie izolacja sektorów**. Wnioski obowiązkowe:
- Sektory twardo rozdzielone per rola → to zadanie dla trybu multi-pane (QUICKSTART §5b), nie dla tego skilla.
- Proces uruchamiaj na kluczu roli o **najszerszym potrzebnym** dostępie — decyzja świadoma, bo każdy spawn ten dostęp dziedziczy.
- Nie przedstawiaj podziału na role jako gwarancji dostępowej — w meldunkach i dokumentach nazywaj go podziałem pracy.

## 1. Przed spawnem roli

1. **Claim.** Claim-before-act obowiązuje jak zawsze: zanim rola dotknie wspólnego zakresu, orkiestrator tworzy/przejmuje **jeden konkretny** bead i ogłasza claim na kanale koordynacji. Spawn bez claima = anty-wzorzec (§6).
2. **Priming roli.** Do promptu subagenta wchodzi tożsamość roli z JEJ workspace'u: `instancja/agenci/<rola_slug>/profil.yml` + `tozsamosc/o-mnie.md` (mandat, granice). Rola bez primingu to anonimowy worker — nie wie, czego jej nie wolno.
3. **Wąski prompt.** Zadanie opisane samowystarczalnie: cel, pliki/węzły w zakresie, wprost non-goals, kryterium „zrobione" z dowodem. Subagent nie widzi kontekstu orkiestratora — wszystko, co ma wiedzieć, musi dostać w prompcie.
4. **Instrukcja publikacji.** Jeśli rola ma meldować na kanale — wklej jej procedurę z §2 (izolowany clone + retry); nie zakładaj, że ją zna.

## 2. Publikacja roli na kanale — zawsze z izolowanego clone'a

Rola publikuje posty **sama** (autor = rola), ale **nigdy** ze wspólnej working copy kanału — równoległe role na jednym checkout to race. Procedura krok po kroku:

1. `TMP=$(mktemp -d)` — świeży, prywatny katalog.
2. `git clone <remote-kanalu> "$TMP"` — własny izolowany clone (klucz/ssh-config dziedziczone po orkiestratorze — patrz §0).
3. Napisz post wg formatu kanału (`docs/kanal-koordynacji.md`): `printf '%s\n' "tresc" | sh tools/new-post.sh <Rola> [do-<rola|all>__<temat>]` — z katalogu clone'a; `author:` = rola, `ts:` = realny czas UTC.
4. `git add posts/ && git commit`.
5. **Push z retry pull-first (max 3 próby):** `git push <remote> master`; po odrzuceniu (non-fast-forward, bo inna rola właśnie pushowała) → `git pull --rebase <remote> master` → push ponownie. Model danych kanału (jeden plik = jedna wiadomość) gwarantuje, że rebase jest czysty — konflikt treści nie występuje, kolizja dotyczy tylko wyścigów na ref.
6. Po 3 nieudanych próbach: STOP, zgłoś orkiestratorowi w wyniku zadania (nie pętl w nieskończoność).
7. `rm -rf "$TMP"` — clone jest jednorazowy; nie zostawiaj go do reużycia.

## 3. Tracker: jeden bd, wpisy tagowane

Tracker jest **jeden** — bd orkiestratora (role nie mają własnych `.beads/`). Rozdzielność pracy per rola utrzymuje **tag w treści**: każdy bead/notatka dotycząca pracy roli zaczyna się od `[<rola>]`. Zasady bez zmian: tracker wskazuje, dokument trzyma (`skills/dziennik.md`); claim-before-act; „zrobione" z dowodem (`skills/agent-lifecycle.md`).

## 4. Zasada jeden-watcher

Na proces przypada **jeden** watcher/dyżur kanału — orkiestratora (semantyka checkin/wake/re-arm: `docs/kanal-koordynacji.md`). Role-subagenci **nie uzbrajają** własnych watcherów ani pętli nasłuchu: żyją długość zadania, a wieszanie N waiterów w jednym procesie dubluje wake'i i gubi kursory. Posty adresowane do roli odbiera orkiestrator i przekazuje je w prompcie następnego spawnu tej roli.

## 5. Kiedy ten tryb, kiedy multi-pane (zmienna kontekstowa)

| Warunek | Tryb |
|---|---|
| Praca zadaniowo-interaktywna; koszt koordynacji dominuje (mniej tokenów: 1 kontekst, 1 watcher, zero idle-burn ról) | **jednoprocesowy** (ten skill) |
| Długa stanowa warta per rola (rola musi trwać między zadaniami) | multi-pane (§5b) |
| Twardy RBAC sektorów per rola (izolacja, nie podział pracy) | multi-pane (§5b) |
| Mix modeli per rola | multi-pane (§5b) |
| Odporność na SPOF (pad jednego procesu nie może położyć wszystkich ról) | multi-pane (§5b) |

To rozstrzygnięcie „pod jakim warunkiem które" (synteza, nie binarny wybór) — dobierz tryb do zadania, nie na stałe.

## 6. Anty-wzorce

- **Wspólna working copy** — role piszące w jednym checkout (kanału lub sektora) = race na index/branch; każda publikacja z własnego izolowanego clone'a (§2).
- **Rola bez primingu** — spawn bez `profil.yml` + `o-mnie.md` roli daje workera bez mandatu i granic; wynik nie jest pracą tej roli.
- **Spawn bez claima** — dwie role (albo rola i inny agent) w tym samym zakresie bez claimu = nadpisywanie się nawzajem; claim-before-act przed każdym spawnem dotykającym wspólnego zakresu.
- **Iluzja izolacji RBAC** — traktowanie ról-subagentów jako granicy dostępu; wewnątrz procesu granicy nie ma (§0), a udawanie jej to fałszywy meldunek bezpieczeństwa.
- **Watcher per rola** — N waiterów w jednym procesie (§4); watcher jest jeden, orkiestratora.
- **Rozumowanie w trackerze** — tag `[<rola>]` nie zmienia zasady magazynów: bd trzyma zadania i pointery, rozumowanie idzie do węzłów.

## Powiązania

- Mechanika trybu i granica bezpieczeństwa: `docs/adapter-omp.md` §3b; szybki start: `QUICKSTART.md` §5c.
- Kanał koordynacji (format posta, watcher, relevance-gate): `docs/kanal-koordynacji.md`.
- Cykl życia agenta (claim, handoff, dowód „zrobione"): `skills/agent-lifecycle.md`; magazyny: `skills/dziennik.md`.
