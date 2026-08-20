# Ontologia węzłów (Szem)

> Rdzeń formatki: **jak strukturyzujemy wiedzę**. Wiedza w Szem to nie płaskie notatki ani tagi — to **typowane węzły** o rolach epistemicznych, powiązane w DAG, z regułami metody wbudowanymi w samą strukturę. Warstwa dostępu (role→sektory, `docs/model-dostepu.md`, `templates/matryca-rbac.md`) jest OSOBNA i cieńsza — sektor grupuje węzły, ale nie definiuje ich sensu.
>
> Zasada nadrzędna (z niej wynika reszta): **żadnej tezy bez dowodu; nie zakładaj — sprawdź.** Forma istnieje, by WYMUSIĆ myślenie, nie udawać je. Dokumentujemy *rozumowanie*, nie sam wynik.

## 1. Typy węzłów

| type | rola epistemiczna | wymaganie |
|---|---|---|
| `cel` | po co, dla kogo | mierzalny sukces + **kryterium falsyfikowalne** + zakres |
| `teza` | proponowane podejście | musi istnieć realna Antyteza (patrz §3) |
| `antyteza` | najmocniejszy kontrargument | **steelman ≥3 punkty** z dowodów, nigdy strawman |
| `synteza` | rozstrzygnięcie | **zmienna kontekstowa** (nie binarny wybór) + **kryterium obalenia** z góry |
| `decyzja` (ADR) | podjęta decyzja | Reject/Implements/Reversibility/Action-items |
| `ewaluacja` | żywy stan + dowody | ledger: ✅(z liczbą)/❌(z proweniencją)/🔄 (patrz §5) |
| `fakt` | zmierzony/zweryfikowany fakt | dowód (komenda / plik:linia / liczba) |
| `architektura` | struktura systemu | odwzorowuje realny byt, nie życzenie |
| `eksperyment` | test/A-B | baseline + próg z góry + wynik z CI/wariancją |
| `runbook` | procedura | kroki weryfikowalne z bajtów |
| `reference` | materiał zewnętrzny | źródło + data dostępu |
| `index` | mapa nitki | tabela T↔AT→S + decyzje + link do Celu/Ewaluacji |

## 2. Frontmatter (każdy węzeł)

```yaml
type:        # jeden z §1
id:          # unikalny, namespaced (np. PROJ-T1)
title:       # zwięzły
status:      # aktywny | obalony | zdemotowany | szkic | zamknięty
parents:     # [id, ...] — DAG, nie drzewo
author:      # kto
date:        # źródło/autorstwo (może być wsteczne)
created_at:  # maszynowe wejście do repo (niezmienne; date != created_at)
```

- **id unikalne + namespaced**, **basename pliku unikalny** (link po nazwie).
- `parents` buduje DAG rozumowania (Synteza ma parents = [Teza, Antyteza]).
- `date` ≠ `created_at`: pierwsze = autorstwo/źródło; drugie = niezmienne wejście do repo (z gita, nie z FS).

## 3. Dialektyka: Cel → Teza ↔ Antyteza → Synteza → Decyzja

- **Test „czy to Teza":** jeśli nie umiesz w JEDNYM zdaniu napisać realnie przekonującej Antytezy → to nie Teza, to **Decyzja (ADR)**. Teza wymusza myślenie o alternatywach, nie racjonalizację po fakcie.
- **Antyteza = steelman ≥3** punktów z dowodów. Strawman jest błędem, nie skrótem.
- **Synteza rozstrzyga przez zmienną kontekstową** (nie „T czy AT" binarnie, lecz „pod jakim warunkiem które") i **wychodzi z kryterium obalenia** — konkretny test/pomiar/próg z góry, który może OBLAĆ. Bez kryterium obalenia synteza jest co najwyżej *zrozumiana*, nie *sprawdzona*.
- **Dlaczego sama dialektyka nie wystarcza:** synteza może być czysta, spójna i FAŁSZYWA — łapie to dopiero Ewaluacja (empiria), nie rozumowanie. Stąd każda synteza z doczepionym warunkiem obalenia.

## 4. Cztery bramki jakości (potrzebne WSZYSTKIE — każda łapie inny błąd)

| # | bramka | pyta | łapie |
|---|---|---|---|
| 0 | logiczno-definicyjna | terminy zdefiniowane? twierdzenie falsyfikowalne? | bełkot |
| 1 | epistemiczna (dialektyka) | rozumiem czy papuguję? | wykucie formy |
| 2 | empiryczna (ewaluacja) | prawdziwe w świecie? | proxy / pareidolia |
| 3 | na ramę (zewnętrzność) | właściwa rama/pytanie? | ślepota ramy |

- Bramka 3 **nie jest w pełni automatyzowalna** (self-reference wall): co w pełni wyspecyfikujesz, jest wewnątrz ramy. ~80% łapie tani automat, ogon — człowiek z własną stawką. Marker zewnętrzności = **obojętność, nie opór**.
- **Konwergencja = czujnik dymu, nie potwierdzenie.** „Wszystko się spina" jest zdarzeniem najbardziej wartym nieufności — realny atraktor musi przetrwać atak na ramę.
- Agent-LLM jest stronniczy ku zgodzie: **waż niezgodę ciężej niż zgodę.**

## 5. Pętla empiryczna i żywy ledger

- **Tylko twierdzenia z metryką** przechodzą pętlę: `Sanity → Problem → Baseline (+próg z góry) → Metoda → Weryfikacja (CI/p vs baseline vs próg)`. Kolejność celowa: **mierz zanim szukasz rozwiązania** (lek na confirmation bias). Próg definiujesz PRZED testem (anty-HARKing).
- **Węzeł `ewaluacja` = żywy ledger** (jedno źródło stanu nitki): `✅ Działa` z LICZBĄ · `❌ Nie działa/otwarte` z proweniencją+datą · `🔄 Co się zmieniło`. Aktualizowany po każdym istotnym kroku.
- **Granica:** proces / konwencja / ADR (bez metryki) → pętla NIE obowiązuje; bramka = dialektyka. Nie rób cargo-cultu.

## 6. Cykl życia węzła

- **Status jawny** we frontmatter. Obalony węzeł **demotujesz, nie kasujesz**: `status: obalony` + co obaliło + data + dowód. Historia rozumowania (w tym pomyłki) = korpus, nie śmieć — paliwo dla przyszłej bramki-3.
- **Proweniencja wszędzie:** każde `❌` i każde twierdzenie statusowe („działa", „zmierzone", „produkcyjne") niesie dowód (komenda/plik:linia/liczba) albo etykietę **niezweryfikowane**. Atrybucja cudzej decyzji — z linkiem do źródła.
- **Sufit = kompetencje operatora.** Aparat zwiększa ZASIĘG rozumowania, nie PUŁAP. Przebieg automatyczny = generator kandydatów pod triage człowieka, nigdy „praca gotowa".

## 7. Pętla samo-ucząca (anti-collapse)

Jeśli instancja kuruje własne dane treningowe: bramki 2+3 muszą stać się **mechaniczną BRAMKĄ Z PROGIEM** kotwiczoną do prawdy ZEWNĘTRZNEJ (byte-match / held-out nietykalny / człowiek), nie AI-ocena-AI. AI-ocena-AI = sala luster → model-collapse.

## 8. Anty-wzorce (zakazane)

- Węzeł-teza bez realnej antytezy (to ukryta decyzja udająca rozumowanie).
- Synteza bez kryterium obalenia (niesprawdzalna).
- Twierdzenie z metryką bez baseline / z progiem strojonym na teście.
- Kroki metody odklepane bez myślenia (forma bez treści = cargo-cult).
- Kasowanie obalonych węzłów (utrata korpusu) zamiast demote-z-proweniencją.
- Traktowanie zgody/konwergencji jako potwierdzenia zamiast sygnału do nieufności.

## Powiązania

- Dostęp do węzłów (role→sektory, HARD/SOFT, klucze): `docs/model-dostepu.md`, `templates/matryca-rbac.md`.
- Opis sektora jako zbioru węzłów: `templates/sektor-repo-README.md`.
- Klasyfikacja sektora (kandydat→gate): `docs/sector-contract.md`.
