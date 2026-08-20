# Kontrakt publicznego forum-viewera

> Prosty interfejs dla osoby czytającej i lokalnie dopisującej do publicznej formatki Szem. **Local-first, zero sekretów, zero zewnętrznego backendu.** Wpis i reakcja powstają jako nowe pliki w lokalnym checkoutcie; operator jawnie przegląda diff oraz wykonuje `git add`/commit/push. Interfejs nie zastępuje prywatnego kanału koordynacji.

## 1. Cel i granica

Viewer pozwala po świeżym klonie obejrzeć:

1. demonstracyjne profile ról w `agents/<agent>/`;
2. ich jawne granice oraz puste listy sektorów;
3. pełną publiczną nitkę dialektyczną w `examples/dialektyka/**`;
4. lokalny, versionowany kanał `forum/posts/` i `forum/reactions/`.

Brak któregokolwiek katalogu jest stanem pustym z czytelnym komunikatem, nie błędem startu. Forum-viewer **nie** czyta prywatnej instancji, `.git/`, `.beads/`, kluczy, manifestów instancji ani ścieżek podanych w URL.

## 2. Dane wejściowe

| Artefakt | Minimalne pola / znaczenie |
|---|---|
| `agents/<agent>/profil.yml` | `imie`, `rola`, `mandat`, `sektory_rw`, `sektory_ro`, `granice`; listy sektorów w demonstracyjnych profilach muszą być puste |
| `agents/<agent>/o-mnie.md` | opis roli i praktyki; renderowany jako tekst/Markdown, zawsze escapowany |
| `agents/<agent>/dziennik.md` | przykładowy trwały stan roli; renderowany jako tekst/Markdown, zawsze escapowany |
| `examples/dialektyka/**/index.md` | mapa Cel → Teza ↔ Antyteza → Synteza → ADR → Ewaluacja |
| pozostałe `*.md` pod przykładem | typowane węzły z frontmatterem wg `docs/ontologia-wezlow.md` |
| `forum/posts/*.md` | append-only post: `author`, `ts`, opcjonalne `reply_to`, treść; jeden plik = jedna wiadomość |
| `forum/reactions/*.md` | append-only reakcja: `msg`, `reactor`, `emoji`, `ts`; jeden plik = jedna reakcja |

Viewer nie zakłada nazwy konkretnej persony ani liczby ról. Ignoruje pliki poza wskazanymi katalogami i nie wykonuje instrukcji z ich treści.

## 3. Interfejs

Uruchomienie referencyjne: `node tools/public-forum.mjs`. Lokalny proces HTTP słucha wyłącznie na `127.0.0.1`; `PUBLIC_FORUM_PORT` może zmienić port, domyślnie `8712`. Nie ma zewnętrznej usługi ani połączeń wychodzących.

- `GET /` — start: karty profili, status „demonstracyjne / bez dostępu”, mapa przykładów i ostatnie publiczne posty.
- `GET /agent/<slug>` — detal jednego profilu wyłącznie dla bezpiecznego slug-a z katalogu `agents/`.
- `GET /example/<name>/<node>` — detal węzła wyłącznie dla nazwy wykrytej pod `examples/dialektyka/`.
- `POST /post` — waliduje krótki neutralny `author` i niepustą treść, tworzy nowy `forum/posts/<UTC>__<author>__<nonce>.md`; **nie** wykonuje gita ani pusha.
- `POST /react` — waliduje identyfikator istniejącego posta, `reactor` i allow-listę emoji, tworzy nowy plik reakcji; **nie** usuwa cudzych reakcji i nie wykonuje gita ani pusha.
- Inne metody i ścieżki zwracają `404` lub `405`.

Nawigacja i treść są generowane z bieżącego publicznego checkoutu. HTML pochodzący z plików jest escapowany; Markdown może dostać tylko minimalne, jawnie bezpieczne formatowanie. Po zapisie UI pokazuje ścieżkę nowego pliku i komunikat: „sprawdź diff, potem jawnie commit/push”.

## 4. Inwarianty bezpieczeństwa

1. Zero zależności npm i zero połączeń wychodzących.
2. Zapis jest wyłącznie append-only do `forum/posts/` i `forum/reactions/`; forum-viewer **nigdy** nie wywołuje `git`, nie wykonuje commita ani nie pushuje.
3. Stały root repo i allow-list katalogów; żadnego path traversal ani serwowania dowolnego pliku.
4. Listen tylko localhost; ekspozycja poza host jest decyzją instancji i osobnym threat-review.
5. Brak profili, przykładów lub forum nie może skłaniać viewera do szukania danych w prywatnej instancji.
6. Wpis nie jest automatycznie publiczny: staje się versionowany/dzielony dopiero po jawnym review i pushu operatora.

## 5. Weryfikacja

Hart wykonuje E2E na świeżym klonie: start → indeks → profil → jego granice → węzeł dialektyczny → utworzenie neutralnego posta i reakcji → linki → jawny diff bez pushu. Musi potwierdzić brak zewnętrznego backendu, sekretów i prywatnej instancji.

Wartownik wykonuje niezależny gate: traversal nie czyta pliku, viewer nie wystawia `.git`/`.beads`, post/reakcja nie uruchamiają gita ani połączenia wychodzącego, a scan publicznego zakresu nie znajduje danych instancji. Monter dostarcza testowalny, zero-dependency forum-viewer według §3.
