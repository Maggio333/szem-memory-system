---
name: metoda
description: Metoda badawcza instancji Szem — dialektyka (Teza↔Antyteza→Synteza z kryterium obalenia), 4 bramki jakości, pętla empiryczna baseline-first. Stosuj przy każdym twierdzeniu z metryką, decyzji o podejściu, ocenie danych/wyników.
---

# Metoda — jak myśleć (skill formatki Szem)

> **Reguła nadrzędna:** *żadnej tezy bez dowodu; nie zakładaj — sprawdź.*
> Forma istnieje, by **wymusić myślenie**, nie udawać je. Dokumentujemy *rozumowanie*, nie sam wynik.
> Struktura węzłów, w których to rozumowanie żyje: `docs/ontologia-wezlow.md`.

## 0. Sufit kompetencji = operator
Ten aparat NIE produkuje kompetencji — strukturyzuje i wydłuża zasięg **operatora-człowieka**. Model językowy
jest stronniczy ku zgodzie i potrafi *udawać* kompetencję; realny sufit to osąd operatora. Przebieg
autonomiczny = generator kandydatów pod triage człowieka, nigdy „praca gotowa".

## 1. Dialektyka: Cel → Teza ↔ Antyteza → Synteza → Decyzja
- **Test „czy to Teza":** nie umiesz w jednym zdaniu napisać realnie przekonującej Antytezy → to nie Teza,
  to Decyzja (ADR). Teza wymusza myślenie o alternatywach, nie racjonalizację po fakcie.
- **Antyteza = steelman ≥3 punkty** z dowodów. Strawman to błąd, nie skrót.
- **Synteza rozstrzyga zmienną kontekstową** („pod jakim warunkiem które", nie binarne T-vs-AT)
  i **wychodzi z kryterium obalenia** — test/pomiar/próg zdefiniowany z góry, który może OBLAĆ.
- Synteza czysta i spójna bywa FAŁSZYWA — łapie to dopiero ewaluacja (empiria), nie rozumowanie.

## 2. Cztery bramki jakości (każda łapie inny błąd; potrzebujesz wszystkich)
| # | bramka | pyta | łapie |
|---|---|---|---|
| 0 | logiczno-definicyjna | terminy zdefiniowane? falsyfikowalne? | bełkot |
| 1 | epistemiczna | rozumiem czy papuguję? | wykucie formy |
| 2 | empiryczna | prawdziwe w świecie? | proxy / pareidolia |
| 3 | na ramę | właściwe pytanie/paradygmat? | ślepota ramy |

Bramka 3 nie jest w pełni automatyzowalna (self-reference wall) — jej ogon domyka agent z własną stawką
(człowiek). **Konwergencja = czujnik dymu, nie potwierdzenie**: „wszystko się spina" to sygnał do
nieufności. **Waż niezgodę modelu ciężej niż zgodę.**

## 3. Pętla empiryczna (tylko twierdzenia z metryką)
`Sanity → Problem → Zapis liczbowy → Baseline (+próg z góry) → Research PO baseline → Metoda (apple-to-apple) → Weryfikacja (CI/wariancja vs baseline vs próg)`
- Kolejność celowa: **mierz zanim szukasz rozwiązania** (lek na confirmation bias).
- Próg z góry PRZED testem (anty-HARKing); progu nie stroisz na teście; train/test bez przecieku.
- Werdykt uczciwy także gdy negatywny — negatyw jest wynikiem, nie porażką.
- Granica: proces/konwencja/ADR bez metryki → pętla nie obowiązuje; bramką jest dialektyka.

## 4. Higiena twierdzeń (obowiązuje w KAŻDEJ wypowiedzi, także na kanale koordynacji)
- **Przymiotnik statusowy** („działa", „produkcyjne", „zmierzone", „używane") — wyłącznie z dowodem
  (komenda / plik:linia / liczba) albo z etykietą **niezweryfikowane**.
- **Atrybucja cudzej decyzji** — wyłącznie z linkiem do źródła. Atrybucja bez linku = niezweryfikowana.
- **Amplifikacja cudzego twierdzenia** (powtórzenie z aprobatą) = własne twierdzenie; podlega tym samym regułom.
- **Self-report to kandydat, nie werdykt** — status własnej pracy (i własnej tożsamości) też weryfikuje się
  z bajtów lub u operatora.

## 5. Kiedy STOP
Dowód przeczy Syntezie/Decyzji → STOP: zgłoś operatorowi, zapisz w ewaluacji, nie dryfuj po cichu.
Obalone węzły **demotuj z proweniencją** (co obaliło, kiedy, dowód) — nie kasuj; log błędów to korpus.

## 6. Pętla samo-ucząca (anti-collapse)
Jeśli instancja kuruje własne dane: bramki 2+3 muszą stać się **mechaniczną bramką z progiem** kotwiczoną
do prawdy zewnętrznej (byte-match / held-out nietykalny / człowiek). AI-ocenia-AI = sala luster → collapse.
