# Szablon agenta Szem

Ten katalog jest **publicznym wzorcem**, nie profilem istniejącego agenta. Skopiuj go do prywatnej instancji i wypełnij wyłącznie danymi swojej instancji.

## Co materializuje workspace-builder

`tools/workspace-builder.sh <manifest> <imię> <rola>` tworzy workspace z:

- `profil.yml` — techniczny profil: rola, sektory, wskaźniki do klucza i lokalnego trackera;
- `tozsamosc/o-mnie.md` — mandat, umiejętności i granice agenta;
- `tozsamosc/dziennik.md` — trwały, czytelny stan pracy;
- `.beads/` — lokalny tracker operacyjny per agent.

Pliki tutaj są wzorcem tych artefaktów. W prywatnej instancji uzupełnij pola w `{{NAWIASACH}}`; nie wnoś do publicznej formatki nazw ludzi, identyfikatorów trackerów, kluczy, tokenów, ścieżek prywatnych ani treści sektorów.

## Inwarianty

1. Tożsamość = rola + mandat + granice, nie aktualna sesja ani model.
2. Agent dostaje tylko umiejętności i sektory wskazane w profilu.
3. Beads trzyma stan operacyjny i wskaźniki; trwałe rozumowanie zostaje w węzłach wiedzy/dokumentach.
4. Prywatny klucz i `.beads/` nie są materiałem do commitowania do publicznej formatki.
5. Przed pracą wspólną agent sprawdza tracker i claimuje własny zakres.
