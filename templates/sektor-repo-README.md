# Szablon: README sektor-repo

> Kopiowany do korzenia każdego **HARD**-sektora (osobne repo). Wypełnione pola są PRIVATE razem z sektorem.

```markdown
# Sektor: <nazwa>

- **wrażliwość:** PRIVATE | PUBLIC-AFTER-SCRUB | PUBLIC
- **granica:** HARD (to repo) — klucz per rola, patrz rejestr kluczy instancji
- **role READ:** <role>
- **role WRITE:** <role>
- **zależności:** <sektory> (linki do ich repo/remote)
- **gate:** <kto pełni niezależny gate dla tego sektora>

## Zakres
Jedno-dwa zdania: jaka wiedza tu żyje i jaka NIE (granica z sektorami sąsiednimi).

## Zasady zapisu
1. Sekrety (klucze, tokeny, hasła) NIE żyją w tym repo — tylko wskaźniki, gdzie sekret jest zarządzany.
2. Twierdzenia z metryką lub statusem („działa", „produkcyjne", „zmierzone") — wyłącznie z dowodem
   (komenda, plik:linia, liczba) albo z etykietą **niezweryfikowane**.
3. Atrybucja cudzej decyzji — wyłącznie z linkiem do źródła (post/dokument/commit).
4. Obalone tezy demotuje się z proweniencją (co obaliło, kiedy, dowód) — nie kasuje.
5. Wpisy przechodzą strukturę węzłów formatki (patrz `docs/ontologia-wezlow.md`).
```

## Uwagi

- Sektor **SOFT** (folder we wspólnym repo instancji) używa tego samego nagłówka jako frontmatter
  pliku `_sektor.md` w swoim folderze — jednolity opis niezależnie od twardości granicy.
- Zmiana wrażliwości sektora (np. `PRIVATE` → `PUBLIC-AFTER-SCRUB`) to decyzja gate'u, zapisywana
  jako ADR w instancji, nigdy cicha edycja nagłówka.
