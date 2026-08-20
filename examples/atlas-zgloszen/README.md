# Atlas Zgłoszeń — fikcyjna instancja przykładowa

> **To jest przykład dydaktyczny, nie działająca instancja ani kopia prywatnej pracy.** Wszystkie role, zakresy, zdarzenia i liczby są wymyślone do pokazania mechaniki Szem. Nie zawiera kluczy, hostów, ścieżek prywatnych, identyfikatorów trackerów, danych klientów ani dostępu do prawdziwych sektorów.

„Atlas Zgłoszeń” to sztuczny projekt: zespół porządkuje 16 syntetycznych kart zgłoszeń przed przekazaniem ich do właściciela. Celem nie jest automatyzacja decyzji, lecz czytelny podział odpowiedzialności, mierzalne kryterium oraz ślad rozumowania.

## Cztery fikcyjne role

| Agent | Mandat w przykładzie | Smaczek pracy |
|---|---|---|
| [`Monter01`](agenci/Monter01/) | przekuwa zaakceptowaną decyzję w małe, weryfikowalne kroki dostawy | „wynik, nie życzenie” — krok bez obserwowalnego końca wraca do rozpisania |
| [`Hart01`](agenci/Hart01/) | pilnuje baseline’u i warunków pomiaru | nie nazwie czegoś szybszym, dopóki nie ma miary i porównywalnych warunków |
| [`Latarnik01`](agenci/Latarnik01/) | mapuje zakres, właściciela i bezpieczny handoff | najpierw robi mapę niejasności, potem wybiera następny krok |
| [`Wartownik01`](agenci/Wartownik01/) | niezależnie kwestionuje ryzyko i warunki publikacji | zielony status autora to kandydat; liczy się osobny, odtwarzalny dowód |

Nazwy są personami przykładowymi na prośbę autora projektu. Nie są kontami, kluczami, adresami ani deklaracją dostępu do prywatnej instancji.

## Ślad dialektyczny

[`sektory/atlas-zgloszen/`](sektory/atlas-zgloszen/) zawiera pełną, fikcyjną nitkę w układzie Obsidianowym: Cel → Teza ↔ Antyteza → Synteza → ADR → Ewaluacja, z `INDEX.md` jako mapą. Wszystkie dokumenty są oznaczone jako szkic przykładowy; ich kryteria są planem walidacji, nie raportem z rzeczywistej produkcji.
