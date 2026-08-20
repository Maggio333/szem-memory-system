# Szem — Memory System

> **Szem** (hebr. *shem* — słowo, imię) = trwały, samo-korygujący się substrat pamięci pod dowolny system agentyczny. W micie golem (ciało) jest martwy, dopóki *szem* (słowo) go nie ożywi — tu: agent (model) ożywa dzięki pamięci i metodzie.

Uniwersalna **formatka** (mechanika + konwencje), na której stawiamy systemy agentyczne: dialektyka (Cel → Teza ↔ Antyteza → Synteza + kryterium obalenia → Decyzja/ADR → Ewaluacja), **4 bramki jakości**, **[katalog 12 grzechów rozumowania](docs/grzechy-rozumowania.md)** (operacyjny checklist bramek), pętla empiryczna baseline-first, żywy ledger, oraz **role-based dostęp do sektorów wiedzy**.

## Strefa publiczna
To repo jest **jawną strefą publiczną** projektu: wszystko tutaj jest pisane i utrzymywane jako publiczne.
- **ZERO treści instancji prywatnej** (nazwy projektów, aplikacji, osób, ścieżki bezwzględne, szczegóły architektury klienta).
- **Clean-from-first-commit**: git pamięta historię — nic wrażliwego nie może tu wpaść nawet przejściowo. Materiał wchodzi tylko: (a) napisany od zera jako publiczny, albo (b) przepuszczony przez scrub-gate.
- Prywatna instancja (agenci, beady, wiedza konkretnych aplikacji) żyje w **osobnym, prywatnym repo** i tylko *importuje* tę formatkę (granica IP = granica repo).

## Model dostępu (mechanika)
Twarda izolacja sektorów wiedzy = na poziomie **repo/remote/klucza per rola** (git nie ma per-path ACL). Sektory wrażliwe = osobne repo/remote z własnym kluczem; reszta = miękko folderami. Static-first (uprawnienia git); warstwa retrieval/RAG dopiero gdy skala wymusi (v2), wtedy index per-sektor.

## Status
**v0 — formatka z narzędziami obu stron adaptera.** Mechanika (`docs/`), skille (`skills/`) i szablony (`templates/`) są na miejscu; stawianie instancji działa end-to-end: serwer (`tools/bootstrap-instancji.sh`), klient (`tools/workspace-builder.sh` + `tools/start.bat` — Windows-entry). Wypełnianie sektorów treścią i hartowanie idą iteracyjnie.

**Start:** [`QUICKSTART.md`](QUICKSTART.md) — od `git clone` do działającej instancji z agentem w 6 krokach.

## Publiczny przykład
[`examples/atlas-zgloszen/`](examples/atlas-zgloszen/) pokazuje **cztery jawnie fikcyjne persony** (`Monter01`, `Hart01`, `Latarnik01`, `Wartownik01`) oraz kompletną nitkę w układzie Obsidianowym: Cel → Teza ↔ Antyteza → Synteza → ADR → Ewaluacja. To materiał dydaktyczny: nie jest instancją, nie przyznaje dostępu, a wszystkie role, zakresy i dane są syntetyczne. Czytaj od [`examples/atlas-zgloszen/README.md`](examples/atlas-zgloszen/README.md).

## Metoda (rdzeń)
Substrat jest nośnikiem **metody**: każde twierdzenie z metryką przechodzi 4 bramki (0 logiczno-definicyjna · 1 epistemiczna · 2 empiryczna · 3 na ramę), a sposób myślenia pilnowany jest **[katalogiem 12 grzechów rozumowania](docs/grzechy-rozumowania.md)** — każdy grzech to antyteza-objaw, synteza i test, który łapiesz u samego siebie. Pełna metoda: `skills/metoda.md`; ślad pracy: `skills/dziennik.md`.

## Podstawa
Szem jest **harness-agnostyczny**: formatka działa pod dowolny system agentyczny, wpięty przez warstwę adaptera (`docs/adapter-omp.md`, kontrakt §2). Substratu (pamięć + metoda) nie wiążemy z jednym harnessem.

**Dedykujemy jednak pierwszeństwo inicjatywom, które wspieramy — obecnie [Omp (oh-my-pi)](https://github.com/can1357/oh-my-pi):** to domyślna, w pełni zintegrowana ścieżka, dopracowana end-to-end:
- **ładowanie zależności** — preflight harnessu i trackera ([`QUICKSTART.md`](QUICKSTART.md) → *Wymagania*: `omp --version`, `bd --version`);
- **konfiguracja i tożsamość** — profil oraz klucz roli per agent;
- **wielu agentów naraz** — izolowane profile OMP (`omp --profile=<agent>`), patrz [`QUICKSTART.md`](QUICKSTART.md) → *Wielu agentów naraz*.

Inne systemy agentyczne są **pluggable**: dostarcz adapter spełniający kontrakt, a substrat działa bez zmian. Doceniamy pracę ekosystemu Ompa i chętnie go wspieramy — zgłoszenia, poprawki i integracje wracają do projektu.

## Autor
Metoda (dialektyka, 4 bramki, katalog grzechów) i architektura substratu: **Arkadiusz Słota** (zob. [NOTICE](NOTICE)).

## Licencja
Copyright © 2026 Arkadiusz Słota. Licencja: [Apache-2.0](LICENSE) — używaj, forkuj, integruj; wymagane zachowanie noty licencyjnej i informacji o prawach autorskich.
