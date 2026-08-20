---
id: R-GRZECHY
title: "Katalog grzechów rozumowania — operacyjny checklist bramek 0–2"
status: aktywny
author: Arkadiusz Słota
---

# Katalog grzechów rozumowania

> Warstwa głębiej niż recenzja. Ten dokument nie ocenia konkretnego wyniku, tylko
> **sposób myślenia o wyniku**. Poligonem jest recenzja, ale grzechy są uniwersalne:
> tak samo wykładają się analizy, syntezy i decyzje.

## Teza nadrzędna

Dobra ocena (i dobra synteza) przechodzi **cztery bramki** (pełny model: `skills/metoda.md`):
- **0 logiczno-definicyjna** — terminy zdefiniowane/pierwotne, twierdzenie falsyfikowalne (łapie bełkot/GIGO);
- **1 epistemiczna** — czy *rozumiem*, czy papuguję (antywzorzec na wykucie wierszyka);
- **2 empiryczna** — **warunek obalenia**: test/liczba/próg, który mógł wyjść inaczej;
- **3 na ramę** — czy w ogóle zadałem właściwe pytanie (zewnętrzność; nie w pełni automatyzowalna).

**Te 12 grzechów to operacyjny checklist bramek 0–2** — każdy grzech to brak którejś z nich;
bramka 3 (rama) jest warstwą głębiej. Tag `[B0/B1/B2]` przy nagłówku mówi, którą bramkę
dany grzech pilnuje. Antyteza jest podana dosłownie (objaw, jak brzmi na głos), a synteza
zawsze kończy się **testem, który łapie ten grzech u Ciebie samego** — bo własnego błędu nie
złapiesz regułą, którą da się wyrecytować, tylko pytaniem, na które trzeba odpowiedzieć dowodem.

**Brak tagu `[B3]` jest zamierzony:** bramka 3 nie ma checklistu do wyrecytowania — recytowalna
reguła siedziałaby w tej samej ramie (self-reference wall). Łapie ją **zewnętrzna interwencja**
(człowiek z własną stawką), nie 13. test z tej listy.

---

## Katalog

### 1. Ocena po nazwie i wibie  ·  [B2]
- **Antyteza:** „Żółw? Logo to język dla dzieci, niepoważne."
- **Synteza:** oceniaj treść i mechanizm, nie etykietę. Nazwa nie jest dowodem.
- **Test:** czy moja ocena przetrwałaby, gdyby projekt nazywał się inaczej?

### 2. Halucynacja liczb / wniosek z dupy  ·  [B2]
- **Antyteza:** „Osiąga 94% skuteczności" (liczba, której nigdzie nie ma).
- **Synteza:** każda liczba ma źródło i kontekst pomiaru, albo nie pada.
- **Test:** czy umiem wskazać plik/run/tabelę, z której pochodzi ta liczba?

### 3. Cargo-cult autorytetu  ·  [B0]
- **Antyteza:** „To narusza twierdzenie Gödla i RODO, więc się nie skaluje."
- **Synteza:** autorytet cytuj tylko tam, gdzie realnie obowiązuje; pokaż związek.
- **Test:** czy potrafię w jednym zdaniu wyjaśnić, *jak* ta zasada tu działa?

### 4. Ekstrapolacja z jednej próbki na całość  ·  [B2]
- **Antyteza:** „Widziałem jeden plik z błędami, więc cały dataset jest zepsuty."
- **Synteza:** wniosek o całości wymaga rozkładu, nie pojedynczego przypadku.
- **Test:** sprawdziłem rozkład po plikach, czy uogólniłem z n=1?

### 5. Skala mylona z jakością (non sequitur)  ·  [B0]
- **Antyteza:** „Mały model, więc słaby."
- **Synteza:** rozmiar to nie jakość; zmierz na zadaniu, nie na liczbie parametrów.
- **Test:** czy mam wynik na zadaniu, czy tylko intuicję o wielkości?

### 6. Wewnętrzna sprzeczność  ·  [B0]
- **Antyteza:** „Najgorszy projekt, jaki widziałem. I zarazem najlepszy."
- **Synteza:** jedna teza na jeden obiekt; sprzeczność to brak tezy.
- **Test:** czy moje dwa zdania o tym samym dadzą się utrzymać naraz?

### 7. Ad hominem / moralizowanie  ·  [B0]
- **Antyteza:** „Prawdziwy ekspert by się nie uczył, to Cię dyskwalifikuje."
- **Synteza:** oceniaj pracę, nie osobę; proces nauki to nie wada.
- **Test:** czy moja uwaga dotyczy artefaktu, czy autora?

### 8. Uśrednianie niewspółmiernych metryk  ·  [B0]
- **Antyteza:** „Słowa układają się w 100%, hasło w 0,1%, więc działa w 50%."
- **Synteza:** różne osie raportuj osobno; średnia z jabłek i sekund to liczba-śmieć.
- **Test:** czy te dwie liczby mierzą to samo? Jeśli nie, czemu je uśredniam?

### 9. Cargo-cult fix  ·  [B1]
- **Antyteza:** „Dodaj blockchain. Przepisz w Haskellu. Wrzuć mikroserwisy."
- **Synteza:** fix wynika z konkretnej diagnozy, nie z mody.
- **Test:** czy potrafię nazwać problem, który ta zmiana rozwiązuje?

### 10. Niefalsyfikowalny bełkot  ·  [B0]
- **Antyteza:** „Wibruje potencjałem, brak synergii, mało AI-first."
- **Synteza:** każde zdanie oceny musi dać się obalić obserwacją.
- **Test:** co konkretnie musiałoby być prawdą/fałszem, żeby to zdanie upadło?

### 11. Ocena bez czytania  ·  [B2]
- **Antyteza:** „Nie otwierałem, ale..."
- **Synteza:** zakres oceny = zakres tego, co realnie przeczytałeś; resztę nazwij pytaniem.
- **Test:** czy każde moje twierdzenie dotyczy materiału, który widziałem?

### 12. Zero różnicowania  ·  [B2]
- **Antyteza:** „Każdy projekt 6/10, nie chciało mi się różnicować."
- **Synteza:** ta sama ocena wszędzie = sygnał, że nie patrzyłeś, nie że są równe.
- **Test:** czym konkretnie różni się moja ocena projektu A od B?

---

## Jak używać

- **Jako checklist recenzenta:** przed wysłaniem oceny przejdź 12 testów; każdy „nie wiem"
  to grzech do naprawienia, nie do ukrycia.
- **Jako moduł szkoleniowy:** najpierw pokaż okaz slopu (antytezy razem = parodia-recenzja),
  potem nazwij grzech, potem wersję z dowodem. Uczy się na kontraście.
- **Jako warstwa metody:** te grzechy to nie tylko recenzje — to ogólne tryby porażki
  rozumowania. Ten sam katalog łapie złą analizę, złą syntezę i złą decyzję.

> Spójność meta: dokument o bramkach sam ma bramki. Jego warunek obalenia: jeśli istnieje
> realny grzech recenzji, którego żaden z 12 testów nie łapie — katalog jest niepełny i rośnie.

## Powiązania
`skills/metoda.md` (4 bramki, dialektyka) · `skills/dziennik.md` (ślad pracy) · `docs/sector-contract.md`.
