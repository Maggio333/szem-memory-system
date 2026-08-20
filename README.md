# Szem — Memory System

> **Szem** (hebr. *shem* — słowo, imię) = trwały, samo-korygujący się substrat pamięci pod dowolny system agentyczny. W micie golem (ciało) jest martwy, dopóki *szem* (słowo) go nie ożywi — tu: agent (model) ożywa dzięki pamięci i metodzie.

Uniwersalna **formatka** (mechanika + konwencje), na której stawiamy systemy agentyczne: dialektyka (Cel → Teza ↔ Antyteza → Synteza + kryterium obalenia → Decyzja/ADR → Ewaluacja), **4 bramki jakości**, **[katalog 12 grzechów rozumowania](docs/grzechy-rozumowania.md)** (operacyjny checklist bramek), pętla empiryczna baseline-first, żywy ledger, oraz **role-based dostęp do sektorów wiedzy**.

## Strefa publiczna
To repo jest **jawną strefą publiczną** projektu: wszystko tutaj jest pisane i utrzymywane jako publiczne.
- **ZERO treści instancji prywatnej** (nazwy projektów, aplikacji, osób, ścieżki bezwzględne, szczegóły architektury klienta).
- **Clean-from-first-commit**: git pamięta historię — nic wrażliwego nie może tu wpaść nawet przejściowo. Materiał wchodzi tylko: (a) napisany od zera jako publiczny, albo (b) przepuszczony przez scrub-gate.
- Prywatna instancja (agenci, beady, wiedza konkretnych aplikacji) żyje w **osobnym, prywatnym repo** i tylko *importuje* tę formatkę (granica IP = granica repo). Publiczna formatka opisuje mechanizm, nie kopiuje stanu instancji.

## Model dostępu (mechanika)
Twarda izolacja sektorów wiedzy = na poziomie **repo/remote/klucza per rola** (git nie ma per-path ACL). Sektory wrażliwe = osobne repo/remote z własnym kluczem; reszta = miękko folderami. Static-first (uprawnienia git); warstwa retrieval/RAG dopiero gdy skala wymusi (v2), wtedy index per-sektor.

## Operacyjnie: Beads per agent
**Używamy [Beads](https://github.com/gastownhall/beads) jako domyślnego trackera operacyjnego**, nie jako pamięci długotrwałej ani wspólnej bazy agentów.

| Magazyn | Co w nim zostaje |
|---|---|
| Profil i `o-mnie.md` | tożsamość, mandat, granice i capability agenta |
| Lokalny Beads | jeden sprawdzalny wynik, claim i krótki wskaźnik do trwałej wiedzy |
| Węzły i dokumenty sektorów | rozumowanie, dowody, decyzje i kontekst, który ma przetrwać |
| Kanał koordynacji | handoffy, pytania i bieżące meldunki |

`workspace-builder` tworzy dla każdego agenta osobny, bezremote’owy workspace z lokalnym `.beads/`. Seeduje trzy neutralne kroki pierwszego dyżuru: profil-check, przeczytanie metody i dziennika oraz potwierdzenie mandatu/granic z wyborem bezpiecznego zakresu. Re-run nie dubluje tych zadań ani nie nadpisuje prywatnego dziennika.

Zasady pracy są proste: jeden bead = jeden obserwowalny wynik; przed wspólną zmianą jest claim; przy handoffie zadanie ma stan, właściciela blokera i następny krok. **Beads wskazuje, dokument trzyma** — do trackera nie kopiujemy długiego rozumowania, sekretów, kluczy, tokenów, pełnych prywatnych ścieżek ani danych sektorów. `.beads/` jest runtime-only: nie commitujemy go i nie synchronizujemy z publicznym repo. Pełny cykl: [`skills/agent-lifecycle.md`](skills/agent-lifecycle.md); instalacja: [`QUICKSTART.md`](QUICKSTART.md).

## Status
**v0 — formatka z narzędziami obu stron adaptera.** Mechanika (`docs/`), skille (`skills/`) i szablony (`templates/`) są na miejscu; stawianie instancji działa end-to-end: serwer (`tools/bootstrap-instancji.sh`), klient (`tools/workspace-builder.sh` + `tools/start.bat` — Windows-entry). Wypełnianie sektorów treścią i hartowanie idą iteracyjnie.

**Start:** [`QUICKSTART.md`](QUICKSTART.md) — od `git clone` do działającej instancji z agentem w 6 krokach.

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
