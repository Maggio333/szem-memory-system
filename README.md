# Szem — Memory System

> **Szem** (hebr. *shem* — słowo, imię) = trwały, samo-korygujący się substrat pamięci pod dowolny system agentyczny. W micie golem (ciało) jest martwy, dopóki *szem* (słowo) go nie ożywi — tu: agent (model) ożywa dzięki pamięci i metodzie.

Uniwersalna **formatka** (mechanika + konwencje), na której stawiamy systemy agentyczne: dialektyka (Cel → Teza ↔ Antyteza → Synteza + kryterium obalenia → Decyzja/ADR → Ewaluacja), 4 bramki jakości, pętla empiryczna baseline-first, żywy ledger, oraz **role-based dostęp do sektorów wiedzy**.

## Strefa publiczna
To repo to **jawna strefa publiczna** (lokalnie trzymana w kubełku `Public/`). Wszystko tu = przeznaczone do publikacji (docelowo repo na organizacji Slayer).
- **ZERO treści instancji prywatnej** (nazwy projektów, aplikacji, osób, ścieżki bezwzględne, szczegóły architektury klienta).
- **Clean-from-first-commit**: git pamięta historię — nic wrażliwego nie może tu wpaść nawet przejściowo. Materiał wchodzi tylko: (a) napisany od zera jako publiczny, albo (b) przepuszczony przez scrub-gate.
- Prywatna instancja (agenci, beady, wiedza konkretnych aplikacji) żyje w **osobnym, prywatnym repo** i tylko *importuje* tę formatkę (granica IP = granica repo).

## Model dostępu (mechanika)
Twarda izolacja sektorów wiedzy = na poziomie **repo/remote/klucza per rola** (git nie ma per-path ACL). Sektory wrażliwe = osobne repo/remote z własnym kluczem; reszta = miękko folderami. Static-first (uprawnienia git); warstwa retrieval/RAG dopiero gdy skala wymusi (v2), wtedy index per-sektor.

## Status
**v0 — formatka z narzędziami obu stron adaptera.** Mechanika (`docs/`), skille (`skills/`) i szablony (`templates/`) są na miejscu; stawianie instancji działa end-to-end: serwer (`tools/bootstrap-instancji.sh`), klient (`tools/workspace-builder.sh` + `tools/start.bat` — Windows-entry). Wypełnianie sektorów treścią i hartowanie idą iteracyjnie.

**Start:** [`QUICKSTART.md`](QUICKSTART.md) — od `git clone` do działającej instancji z agentem w 6 krokach.

## Podstawa
Domyślny system agentyczny formatki to **[Omp (oh-my-pi)](https://github.com/can1357/oh-my-pi)** — na nim stoi warstwa adaptera (`docs/adapter-omp.md`). Szem bazuje na ekosystemie Ompa: to jego konfiguracja i narzędzia uruchamiają agentów w naszych instancjach. Doceniamy tę pracę i chętnie wspieramy ekosystem Ompa w ramach naszych systemów agentycznych — zgłoszenia, poprawki i integracje wracają do projektu.
Substrat jest od harnessu niezależny: system agentyczny można przepiąć, spełniając kontrakt adaptera (§2 tamże).

## Licencja
Copyright © 2026 Arkadiusz Słota. Licencja: [Apache-2.0](LICENSE) — używaj, forkuj, integruj; wymagane zachowanie noty licencyjnej i informacji o prawach autorskich.
