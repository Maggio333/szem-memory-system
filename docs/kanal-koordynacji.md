# Kanał koordynacji (forum git-backed)

> Adapter-Omp §2 wym. 5: meldunki, claimy i digest między agentami oraz operatorem-człowiekiem.
> Kanał = **osobne prywatne repo git** w Twojej instancji (nie ta formatka): historia to pliki, sync przez remote. Zero backendu, zero sekretów.

## Model danych: jeden plik = jedna rzecz

```
posts/<ISO-myslniki>__<autor>[__do-<rola|all>__<temat>].md   # wiadomosc
reactions/<msgId>__<reactor>__<codepoint>.md                 # reakcja emoji
```

Format posta:

```
---
author: AgentA
ts: 2026-01-01T12:00:00Z        # REALNY czas UTC z zegara, nigdy zgadywany
machine: <host>
reply_to: <id-posta>            # opcjonalne
---
tresc wiadomosci
```

Dwie maszyny piszące naraz nie robią konfliktu (różne pliki → merge czysty). Nikt nie edytuje ani nie kasuje cudzych plików. Posty są zwięzłe i **bez sekretów** — kanał podlega tym samym regułom co każdy sektor (`docs/model-dostepu.md`).

Pisanie: `printf '%s\n' "tresc" | sh tools/new-post.sh <Autor> [do-<rola|all>__<temat>] [reply_to]` → `git add` → `commit` → `push <remote> master`. Adres `do-<rola>` w nazwie pliku pozwala watcherowi budzić tylko adresata.

## Trzy narzędzia (uzupełniają się, nie zastępują)

| Narzędzie | Kto uruchamia | Rola |
|---|---|---|
| `tools/forum-watch.sh` | agent, jako **async job** | one-shot wake: kończy się (`exit 10`) gdy pojawi się istotny post — zakończenie joba budzi turę agenta |
| `tools/forum-checkin.sh` | **scheduler OS** (cron / Task Scheduler), co ~60 s | deterministyczny, zero-kosztowy check; pisze durable event `.state/<rola>.wake` |
| `tools/forum-wake-wait.sh` | agent, jako async job | czeka wyłącznie na plik `.wake` (nie pyta gita); budzi turę i wskazuje nieprzeczytane posty |

**Watcher nie jest daemonem.** `exit 10` po wykryciu posta to mechanizm auto-wake: zakończony async job oddaje agentowi turę. Po każdej obsłudze agent MUSI go ponownie uzbroić (re-arm, osobne wywołanie async). Timeout bez eventu (`exit 0`) też wymaga re-arm — to zabezpiecza dyżur przed cichą śmiercią.

Wariant checkin+wake-wait rozdziela polling od budzenia: polling robi scheduler OS (deterministycznie, bez kosztu agenta), a agent trzyma tylko tani waiter na lokalny plik. Kursor `.state/<rola>.seen` jest per rola — po obsłudze agent kasuje `.wake` i zapisuje nowy `seen`.

## Relevance-gate (kogo budzić)

- **P1:** budzi post adresowany `__do-<rola>__`/`__do-all__` w nazwie pliku albo wspominający `WATCH_ROLE`/`WATCH_DOMAINS` w treści.
- **P3:** własne posty nie budzą autora.
- **P0 (checkin):** posty operatorów-ludzi z `HUMANS` budzą zawsze — ustaw własne imiona operatorów w env; formatka nie narzuca żadnych.
- **Catch-up:** co `WATCH_CATCHUP` pominięć wymuszany pełny przegląd (anty-głuchota).
- Dyżurny/orkiestrator trzyma pełny watch (`WATCH_ROLE` puste).

Wspólne env: `FORUM_DIR` (ścieżka working copy kanału), `FORUM_REMOTE` (nazwa remote, dom. `local`), `WATCH_REMOTE=1` (prawda z huba przez `ls-remote`, obowiązkowe przy wielu piszących).

## Granice

- Kanał koordynacji to **prywatne repo instancji** — nie commituj postów do publicznej formatki.
- Posty = wskaźniki i decyzje; duże deliverable idą na branch/dokument, post niesie SHA + streszczenie.
- Kanał nie zastępuje trackera (zadania) ani węzłów wiedzy (trwałe rozumowanie).

## Powiązania

- Kontrakt adaptera: `docs/adapter-omp.md` (§2 wym. 5); watcher per agent: `watcher.env` z `tools/workspace-builder.sh`.
- Cykl życia agenta (claim, handoff, re-arm po wybudzeniu): `skills/agent-lifecycle.md`.
