---
name: dziennik
description: Jak instancja Szem śledzi i dokumentuje pracę — trzy warstwy pamięci (skille/vault/tracker), reguły styku, anti-rot, utrwalanie. Stosuj przy planowaniu, zakładaniu węzłów, śledzeniu postępu, zamykaniu sesji.
---

# Dziennik — jak zostawiać ślad (skill formatki Szem)

> Para do `skills/metoda.md` (metoda uczy myśleć; ten skill — zostawiać ślad).
> Struktura węzłów: `docs/ontologia-wezlow.md`. Dostęp do sektorów: `docs/model-dostepu.md`.

## 0. Trzy warstwy pamięci (nie duplikuj, nie myl)
| Warstwa | Odpowiada za | Charakter |
|---|---|---|
| **Skille** | METODA: jak myśleć, jak zapisywać, jak wracać po restarcie | stałe, meta, agent-facing |
| **Vault (sektory wiedzy)** | ROZUMOWANIE: węzły dialektyczne + dowody + DLACZEGO; żywe, samo-korygujące | trwałe, git, human+agent |
| **Tracker zadań z pamięcią** (np. beads) | OPERACJA: zadania (co dalej) + szybkie insighty międzysesyjne | operacyjne, wskaźnikowe |

**Reguły styku:**
- **Tracker WSKAZUJE, vault TRZYMA.** Ta sama treść nigdy w dwóch miejscach — tracker trzyma pointer
  (id/ścieżkę węzła), nie kopię rozumowania.
- Pamięci operacyjne trackera = **lokalne per maszyna** (niosą wrażliwy kontekst agenta). Wiedza, która ma
  przeżyć maszynę/agenta → węzeł w vault (git, review-owalny), nigdy surowy zrzut pamięci.
- Żywy stan nitki = **jeden węzeł `ewaluacja`** (jedno źródło prawdy); wszystko inne wskazuje na niego.

## 1. Rytm pracy
- **Start sesji:** prime trackera (kontekst+pamięci) → co gotowe → indeks aktywnej nitki w vault.
- **Przed kodem/analizą:** zadanie w trackerze. **Po każdym istotnym kroku:** aktualizacja węzła `ewaluacja`.
- **Utrwalanie = push, nie commit.** Praca istniejąca tylko w sesji/ulotnym stanie NIE istnieje.
  Meldunek o stanie gita składa się PO weryfikacji zdalnego stanu (ls-remote), nie po stdout pusha.
- **Koniec sesji / zejście z warty:** background-taski ubite, wszystko wypchnięte, stan zapisany
  (pointer w trackerze: co czeka na powrót), jeden meldunek PARKED.

## 2. Zapis węzłów
- Frontmatter obowiązkowy (schema: `docs/ontologia-wezlow.md` §2); id unikalne+namespaced; basename unikalny.
- Realne napięcie z alternatywą → Teza+Antyteza(+Synteza). Decyzja podjęta → ADR. Naprawa >30 min → runbook.
  Test/porównanie → eksperyment (baseline + próg z góry).
- **Anti-rot:** nie pisz dokumentów, których nie czytasz na starcie sesji. Obalone syntezy demotuj
  (status + co obaliło + data + dowód) — nie usuwaj i nie zostawiaj jako zombie w aktywnej ścieżce.
- ❌ w ewaluacji zawsze z proweniencją — log niespójności to korpus, nie śmieć.

## 3. Higiena współpracy wielu agentów
- **Jeden plik = jeden autor naraz** (żywy ledger ma jednego skrybę; cudze dokumenty flagujesz, nie edytujesz).
- **Claim-before-act:** zanim tkniesz wspólną/cudzą domenę — claim na kanale koordynacji + świeży pull;
  działa w obie strony (przejęcie cudzego kroku = claim z oknem STOP).
- **Gate ≠ autor:** treść publikowana poza sektor prywatny przechodzi niezależną parę oczu.
- Meldunek = WYNIK, nie zamiar. Duże treści = branch/dokument, na kanale tylko wskaźnik.

## 4. Restart / ciągłość
- Nowa instancja odzyskuje się z: prime trackera → własny dziennik → kanał koordynacji od ostatniego
  znanego punktu. Wnioski poprzedniej sesji = do-weryfikacji, nie pewnik.
- **Zweryfikuj profil/tożsamość zanim się przedstawisz** (rejestr agentów instancji).
- Spór tożsamości dwóch żywych instancji: kryterium = **wskazanie operatora** (zewnętrzna kotwica),
  nigdy self-report; przegrywająca instancja schodzi z batonem (pointery + kill własnych taśm + zero-in-flight).
