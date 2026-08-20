# Szablon: macierz dostępu rola → sektor

> **Ten plik to SZABLON** (część publicznej formatki). **Wypełniona macierz jest zawsze PRIVATE** — same nazwy sektorów i ról instancji niosą informację o niej. Wypełnienie żyje w prywatnym repo instancji, nigdy w formatce.

## Macierz

| sektor | wrażliwość | granica | repo/remote | role: READ | role: WRITE | zależności | uzasadnienie tagu |
|---|---|---|---|---|---|---|---|
| `<nazwa>` | `PUBLIC` \| `PUBLIC-AFTER-SCRUB` \| `PRIVATE` | `HARD` \| `SOFT` | `<repo lub folder>` | `<role>` | `<role>` | `<sektory>` | wymagane dla `PUBLIC*` |

## Reguły wypełniania

1. **Default-deny**: nowy sektor bez rozstrzygnięcia = `PRIVATE`/`HARD`. `PUBLIC*` wymaga uzasadnienia w ostatniej kolumnie; brak uzasadnienia = tag nieważny.
2. **Tag = kandydat**: wpis w macierzy nadaje autor analizy; **werdykt** nadaje niezależny gate przy materializacji sektora (kolumny nie zmienia autor tagu).
3. **HARD ⇒ osobny wiersz w rejestrze kluczy**: każda para (rola, sektor-HARD) ma dokładnie jeden klucz; współdzielenie klucza między role jest zakazane (rewokacja per-rola musi zostać O(1)).
4. **WRITE ⊂ READ**: rola pisząca zawsze czyta; rola pisząca do sektora `PUBLIC*` przechodzi gate przy każdym pushu.
5. **Zależności są jawne**: jeśli sektor A zależy od B, rola czytająca A zwykle potrzebuje READ na B — brak tego w macierzy to błąd projektowy, nie niedopatrzenie runtime.
6. **Agent publiczny** (wystawiony na nieufne wejście, np. publiczny czat): READ wyłącznie z sektorów `PUBLIC` wskazanych wprost; nigdy klucz do `PRIVATE` (wejście nieufne = kanał eksfiltracji).

## Rejestr kluczy (towarzyszy macierzy, PRIVATE)

| rola | sektor | fingerprint klucza | nadany | odwołany |
|---|---|---|---|---|

Klucz wpisuje się fingerprintem (nigdy materiałem prywatnym). Odwołanie = data + powód; wiersze się nie kasuje (historia rewokacji = część audytu).
