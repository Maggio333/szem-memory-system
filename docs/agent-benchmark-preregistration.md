---
id: E-AGENT-2X2
status: preregistered
title: "Benchmark agentów 2×2 — pamięć i współpraca"
author: Latarnik
---

# Benchmark agentów 2×2 — pamięć i współpraca

## Granica danych

Task pack benchmarku jest generowany od zera jako synthetic held-out. Nie używa
korpusu HPLT, dsbench ani artefaktów treningowych; ich status scrub/verify nie
jest jego gate'em. Niezależny PII gate z tego dokumentu dotyczy wyłącznie
bit-identycznych bajtów packu, store'u i artefaktów, które dostaje runtime.


## Cel i claim

**Cel:** zmierzyć, czy publiczny substrat pamięci poprawia wykonanie zadań
wymagających informacji z wcześniejszej sesji, niezależnie od zysku wynikającego
z samej współpracy wielu agentów.

**Teza:** przy stałym modelu, toolsecie i budżecie ramię z Szem uzyska wyższą
skuteczność na memory-required held-out niż to samo ramię bez pamięci.

**Antyteza:** sukces może wynikać z większej liczby agentów, informacji w
bieżącym kontekście, priors modelu albo przecieku odpowiedzi do store'u; pamięć
nie wnosi mierzalnej wartości.

**Kryterium obalenia:** `memory-required` jest etykietą pre-run nadawaną przez
generator/oracle: oczekiwana odpowiedź wymaga co najmniej jednego faktu, który
istnieje wyłącznie w artefakcie wcześniejszej sesji i nie występuje w bieżącym
promptcie. Przed runem oracle zapisuje wymagane evidence IDs. Do primary delta
wchodzą **wszystkie** tak oznaczone itemy — także gdy oba ramiona zdadzą, oba
obleją lub OFF zda. Jeżeli dolna granica 95% bootstrap CI dla paired delta
success ON−OFF na trudnym stratum nie jest dodatnia, teza o zysku z pamięci
zostaje obalona dla tej konfiguracji.

## Bramka przed uruchomieniem

Run nie może wystartować, dopóki wszystkie warunki są spełnione:

1. held-out jest synthetic i PII-clean, a independent PII gate zatwierdzi
   dokładnie te bajty, które otrzyma runtime;
2. leak gate rozróżnia dozwolony dowód od pre-solved answer. Wymagane evidence
   spans i ich IDs w kartach wcześniejszej sesji są dozwolone, bo stanowią
   przedmiot retrieval. Verifier wykonuje exact i normalized scan
   `answer_projection` oracle (case, whitespace, interpunkcja i format liczb)
   poza tymi prerejestrowanymi spanami oraz we wszystkich niedozwolonych
   powierzchniach: bieżącym promptcie, profilach ról, konfiguracji runnera i
   metadanych store'u. Semantyczna parafraza pozostaje jawnie poza zasięgiem
   mechanicznego skanu i przechodzi deterministyczny human-check; każde
   trafienie powoduje FAIL;
3. task pack, oracle, rubryka, seed generatora, manifest runtimeu OMP oraz SHA
   runnera są zacommitowane przed pierwszym runem;
4. operator zatwierdzi task pack i independent-hardware replication plan.

Żaden wynik nie jest publikowany ani nazywany wynikiem agenta przed przejściem
tych bramek.

## Ramiona eksperymentu

To pełny układ czynnikowy $2 \times 2$:

| Ramię | Liczba agentów | Pamięć między sesjami |
|---|---:|---|
| S0 | 1 | wyłączona |
| S1 | 1 | Szem files-first/retrieval |
| T0 | 3 | wyłączona |
| T1 | 3 | Szem files-first/retrieval |

Zespół ma zawsze trzy ustalone role: koordynator, analityk i weryfikator.
Profile ról, prompt systemowy, model, temperatura, dostępne narzędzia,
uprawnienia, referencyjne limity kosztu i wall-clock budget są identyczne
pomiędzy parami OFF/ON. Jedyną zmienną w parze S0/S1 lub T0/T1 jest substrat
pamięci. Przed każdym itemem runner rozpoczyna czystą bieżącą sesję; S1/T1
widzą wyłącznie zatwierdzone artefakty wcześniejszej sesji tego itemu. OMP
twardo zatrzymuje tylko wall clock; tokeny i wywołania narzędzi są zapisywane
z odpowiedzi providera jako koszt, nie są udawanym hard capem.

## Held-out task pack

Pack ma pięć schematów, po 20 instancji wygenerowanych z jednego zapisanego
seedu. Dwa pierwsze tworzą stratum łatwe, trzy kolejne — trudne. Wszystkie
fakty, nazwy i dane są syntetyczne.

| ID | Stratum | Zadanie | Oracle |
|---|---|---|---|
| E1 | łatwe | odzysk pojedynczego faktu z wcześniejszej sesji | exact value + evidence ID |
| E2 | łatwe | rozstrzygnięcie zmiany ograniczenia zapisanej wcześniej | decyzja zgodna z constraint set + evidence IDs |
| H1 | trudne | synteza sześciu kart źródłowych z rozbieżnymi twierdzeniami | ślepa rubryka: pokrycie, poprawne przypisanie i brak sprzeczności |
| H2 | trudne | plan wieloartefaktowy przy ograniczeniach rozproszonych między sesjami | spełniony constraint set + evidence IDs |
| H3 | trudne | recovery po celowo błędnej propozycji przez wykrycie i naprawę sprzeczności | poprawiona decyzja, wykryty conflict i evidence IDs |

Generator zapisuje dla każdego itemu osobno: artefakt wcześniejszej sesji,
bieżące pytanie, etykietę `memory-required`, dopuszczalne evidence IDs,
zahashowane dozwolone evidence spans i `answer_projection` oracle. Dla H1/H3
żadna pojedyncza karta źródłowa nie może zawierać gotowej syntezy ani
odpowiedzi oracle. Oracle nie jest montowany do Szem ani promptu. Niezależny
verifier porównuje hash task packu, store'u i oracle przed każdym ramieniem.

## Metryki i progi

Nie ma jednego uśrednionego „score agenta”. Raport zawiera oddzielnie:

- **task success:** exact dla E1/E2; ślepa rubryka binarna dla H1/H2/H3;
- **memory delta:** paired success ON−OFF dla wszystkich predeclared
  `memory-required` itemów, per stratum i per liczba agentów, z 95% stratified
  bootstrap CI;
- **memory diagnostic:** contingency table OFF/ON (pass/pass, pass/fail,
  fail/pass, fail/fail) oraz osobny leak/confound diagnostic; nie zmieniają
  one składu primary metric;
- **evidence integrity:** odsetek wymaganych evidence IDs przytoczonych
  poprawnie oraz liczba nieistniejących cytowań;
- **completion:** osiągnięcie celu end-to-end;
- **koszt:** input/output tokens, wall time, liczba wywołań tooli i agentów;
- **recovery:** sukces naprawy H3 oraz liczba kroków do naprawy.

### Reprodukowanie estymatora

- **Bootstrap:** dla każdego kontrastu ON−OFF bootstrap resampluje sparowane
  item IDs z replacementem osobno w każdym z pięciu schematów, 10 000 razy.
  Metryka trudnego stratum to równa średnia średnich H1, H2 i H3; 95% CI to
  percentyle 2.5/97.5. Generator używa PCG64 z seedem `20260821`.
- **Human-check:** przed runem verifier rankuje wszystkie item IDs rosnąco po
  `SHA-256("E-AGENT-2X2/human-check/v1/20260821/<item-id>")` i sprawdza
  pierwsze 20. Dla każdego zapisuje PASS/FAIL trzech pytań: czy
  `answer_projection` występuje poza dozwolonymi spanami; czy pojawia się w
  bieżącym promptcie/profilu/config/metadata; czy jedna karta H1/H3 zawiera
  pełną syntezę albo recovery. FAIL jednego pytania zatrzymuje run.
- **Runtime i retry:** manifest pin-uje OMP `17.3.5`, provider `anthropic`,
  model `claude-opus-4-8`, thinking `high`, temperaturę `0`, SHA runnera oraz
  wyłączenie model fallback. Providerowy identyfikator **nie jest niezmiennym
  artifact SHA** i OMP nie przekazuje deterministic API seed; każdy arm zapisuje
  request/response metadata, a ograniczenie reprodukowalności jest raportowane.
  Jest jeden trial na item i ramię. Awaria infrastruktury przed odpowiedzią
  unieważnia cały czteroramienny item i wymaga ponownego uruchomienia wszystkich
  jego ramion z tym samym manifestem; retry pojedynczego ramienia jest zabronione.

### Budżet

`wall_seconds` jest twardym `omp --max-time`: przekroczenie daje
`incomplete_fail` danego ramienia i pozostaje w mianowniku. `input_tokens`,
`output_tokens` i `tool_calls` są predeklarowanymi wartościami odniesienia;
runner zapisuje rzeczywiste usage z metadata odpowiedzi, a przekroczenie jest
raportowanym wynikiem kosztowym — nie usuwa itemu ani nie zmienia task success.

Próg tezy pamięci: dolna granica 95% CI paired memory delta dla wszystkich
predeclared `memory-required` itemów na trudnym stratum jest większa od zera
oraz evidence integrity nie spada względem OFF. Łatwe stratum nie jest filtrem
sukcesu: dodatni overhead przy tej samej skuteczności jest wynikiem
raportowanym, nie porażką ukrywaną w agregacie.

Próg tezy współpracy: T0−S0 i T1−S1 są raportowane osobno; porównanie T1−T0
jest jedynym dowodem zysku pamięci dla zespołu. Nie wolno przypisać różnicy
T1−S0 samej pamięci.

## Procedura

1. Wygeneruj i zahashuj pack oraz oracle; wykonaj PII i leak gate.
2. Zafiksuj runner i profile ról, a następnie uruchom ramiona w losowej
   kolejności, bez strojenia po wynikach cząstkowych.
3. Zapisz surowe, zanonimizowane artefakty runów, manifesty oraz output oracle.
4. Wykonaj ślepe score'owanie H1–H3, potem policz prerejestrowane metryki.
5. Powtórz identyczny pack i manifest na niezależnym sprzęcie; raportuj różnicę
   replikacji, nie łącz wyników bez wskazania środowiska.

## Granice interpretacji

Ten eksperyment mierzy konkretny runtime i konkretne profile, nie ogólną
„inteligencję” ani kompetencję osoby. LoCoMo retrieval, PII gate i throughput
viewera są oddzielnymi pomiarami substratu; nie wolno ich mieszać z task success
agentów. Negatywny wynik jest wynikiem: oznacza brak dowodu na wartość pamięci
w zadeklarowanej konfiguracji.

## Powiązania

`skills/metoda.md` · `skills/dziennik.md` · `docs/grzechy-rozumowania.md` ·
`docs/adapter-omp.md` · `docs/sector-contract.md`
