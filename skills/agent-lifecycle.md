# Agent lifecycle — tożsamość, Beads i ciągłość

Ten skill jest wzorcem dla agenta Szem niezależnie od harnessu. Konkretne ścieżki, kanały, rejestry i polityki ustala **prywatna instancja**.

## Zasada magazynów

| Magazyn | Przeznaczenie |
|---|---|
| Profil + `o-mnie.md` | tożsamość, mandat, granice i przydzielone capability |
| Beads | zadania, claimy i krótkie wskaźniki operacyjne per agent |
| Węzły/dokumenty sektorów | trwałe rozumowanie, dowody i decyzje |
| Kanał koordynacji | bieżące handoffy, pytania i meldunki |

**Beads wskazuje, dokument trzyma.** Nie kopiuj długiego rozumowania do trackera. Nie używaj lokalnych memories trackera jako mechanizmu udostępniania wiedzy między agentami.

## Start sesji

1. Przeczytaj `profil.yml`, `tozsamosc/o-mnie.md` i ostatni wpis dziennika.
2. Wykonaj profil-check względem rejestru prywatnej instancji. Przy rozbieżności zatrzymaj się i pytaj operatora.
3. Ustaw lokalny katalog trackera i odzyskaj stan:

```sh
export BEADS_DIR="$PWD/.beads"
bd prime
bd list --status=in_progress
bd ready
```

4. Przeczytaj nowe informacje z kanału koordynacji przed pierwszą zmianą.
5. Zanim dotkniesz wspólnego zakresu: sprawdź, czy nie ma właściciela, a następnie utwórz albo przejmij **jeden konkretny** bead i ogłoś claim na kanale instancji.

## Podczas pracy

- Jeden bead opisuje jeden sprawdzalny wynik; notatka beada wskazuje odpowiedni węzeł/dokument.
- Claim przed zmianą; nie nadpisuj cudzej domeny bez handoffu.
- „Zrobione” wymaga dowodu adekwatnego do zmiany: wynik testu, obserwowany scenariusz lub zweryfikowany commit.
- Sekrety, klucze, tokeny, pełne ścieżki prywatne i dane wrażliwe nie trafiają do publicznej formatki, dziennika publicznego ani opisu beada.

## Handoff i restart

1. Zamknij zakończone beady; dla otwartych dopisz stan, właściciela blokera i następny krok.
2. Zapisz zwięzły wpis w `tozsamosc/dziennik.md` z linkiem/wskazaniem do trwałej wiedzy.
3. Przekaż zakres na kanale koordynacji, jeśli inny agent ma przejąć pracę.
4. Po restarcie nie ufaj poprzedniej sesji: ponownie odczytaj profil, tracker, dziennik i stan repo, potem re-claimuj tylko własny zakres.

## Koniec sesji

- Utrwal kod i dokumenty w odpowiednim repo zgodnie z polityką instancji.
- Zamknij lub przekaż wszystkie własne beady.
- Zostaw dziennik z jednym następnym bezpiecznym krokiem.
- Dopiero po trwałym handoffie zatrzymaj watcher/kanał dyżuru.
