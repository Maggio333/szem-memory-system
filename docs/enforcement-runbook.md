# Enforcement runbook — twarda izolacja sektorów (gitolite na dedykowanym userze)

> Status: **aktywny** (zmergowany do main; zweryfikowany e2e na realnej instancji). Operacjonalizuje [model-dostepu.md](model-dostepu.md) §1–2 (HARD = repo/remote/klucz per rola). Generic — zero treści instancji.

## Problem, który to zamyka

`model-dostepu.md` ustala: twarda granica = repo/remote/klucz per rola, bo **git nie ma per-path ACL**. Ale sam „klucz per rola" tego NIE egzekwuje na zwykłym SSH-hubie: jeden użytkownik systemowy z jednym `authorized_keys` daje każdym wpisanym kluczem dostęp do **wszystkich** repozytoriów pod tym kontem. Potrzebny jest mechanizm **per-key → per-repo ACL**. Ten runbook realizuje go przez **gitolite**.

## 0. Zasada izolacji (KRYTYCZNA)

Gitolite **przejmuje `authorized_keys`** użytkownika, na którym działa (zarządza nim wyłącznie z własnej konfiguracji). Dlatego:

- Instaluj gitolite na **DEDYKOWANYM użytkowniku systemowym** (np. `szem-git`), nigdy na żywym użytkowniku huba obsługującym istniejące, load-bearing repozytoria.
- Skutek: kompromitacja/błąd konfiguracji gitolite dotyka wyłącznie sektor-repo instancji, nie reszty infrastruktury git.

## 1. Instalacja (jednorazowo, na dedykowanym userze)

1. Utwórz osobnego użytkownika systemowego `szem-git` (własny home, własny SSH).
2. Zainstaluj gitolite pod tym userem, bootstrapując go **kluczem publicznym administratora** (rola-admin).
3. Gitolite tworzy repo administracyjne `gitolite-admin` — jedyne źródło konfiguracji: reguły dostępu (`conf/gitolite.conf`) i klucze publiczne (`keydir/`) jako **wersjonowane pliki**. Każda zmiana dostępu = commit+push do `gitolite-admin` (audytowalna historia).

## 2. Model: rola ↔ sektor ↔ klucz

- Każda **rola** = para kluczy ed25519. Klucz **prywatny** zostaje u agenta-roli i nigdy nie opuszcza jego maszyny; **publiczny** ląduje w `keydir/<rola>.pub`.
- Każdy **HARD-sektor** = osobne repo (`<sektor>`).
- `conf/gitolite.conf` mapuje repo → role z prawem dostępu, wg macierzy z [templates/matryca-rbac.md](../templates/matryca-rbac.md):
  ```
  repo <sektor>
      R   = <rola-czytajaca-1> <rola-czytajaca-2>
      RW  = <rola-wlasciciel>
  ```
- Inwarianty: **WRITE ⊂ READ**; push do sektora PUBLIC przechodzi przez scrub-gate (poza tym runbookiem); **agent publiczny nigdy nie dostaje klucza do sektora PRIVATE** (patrz model-dostepu.md, anty-wzorce).

## 3. Utworzenie sektor-repo

1. W klonie `gitolite-admin` dopisz blok `repo <sektor>` + reguły `R`/`RW` per rola w `conf/gitolite.conf`.
2. `commit` + `push` → gitolite **automatycznie** tworzy bare-repo po stronie serwera. (Nie tworzy się repo ręcznie na dysku — źródłem jest config.)

## 4. Grant (nadanie dostępu roli)

1. Dodaj `<rola>.pub` do `keydir/`.
2. Dopisz `<rola>` do reguł `R`/`RW` właściwych repo.
3. `commit` + `push` → dostęp aktywny natychmiast.

## 5. Revoke (odebranie dostępu)

- Usuń `<rola>` z reguł danego repo (dostęp do sektora) lub `<rola>.pub` z `keydir/` (całkowita rewokacja) → `commit` + `push`. Rewokacja = edycja configu, O(1).
- Zdarzenie zapisz w rejestrze rewokacji ([templates/matryca-rbac.md](../templates/matryca-rbac.md)) — historia **nie-kasowalna** (audyt).

## 6. Kompozycja meta-repo

- `<instancja>` (meta-repo) = referencje (submodule, pinned) do sektor-repo + import publicznej formatki. Meta-repo trzyma **wskazania**, nie treść sektorów wrażliwych.
- Rola realnie sklonuje tylko te sektory, do których gitolite daje jej klucz; pozostałe submodule pozostają niedostępne (fetch = odmowa).

## 7. Weryfikacja z bajtów — test DWUSTRONNY (kryterium akceptacji)

> Harness MUSI dostarczyć **działający** input po obu stronach — inaczej „wszystko odrzucone" bywa artefaktem (np. zgubiony parametr), nie dowodem izolacji.

- **POZYTYW:** kluczem roli A klonuj sektor A →
  `GIT_SSH_COMMAND='ssh -i <klucz-roli-A> -o IdentitiesOnly=yes' git clone szem-git@<host>:<sektor-A>` → **sukces** (kod 0, repo pobrane).
- **NEGATYW:** **tym samym** kluczem A klonuj sektor B (nie jej) →
  `GIT_SSH_COMMAND='ssh -i <klucz-roli-A> -o IdentitiesOnly=yes' git clone szem-git@<host>:<sektor-B>` → **odmowa** (gitolite: `R any <sektor-B> <rola-A> DENIED`).
- Oba wyniki potwierdzone z bajtów (kod wyjścia + komunikat), nie deklaracją. Negatyw ważny tylko gdy klucz A został faktycznie użyty (potwierdź, że nie zadziałał fallback na inny klucz — stąd `IdentitiesOnly=yes`).

## 8. Bramki

- Gitolite tylko na dedykowanym userze (izolacja od load-bearing huba).
- Klucze prywatne u agentów; w repo/keydir wyłącznie **publiczne**. Sekrety nie żyją w żadnym sektorze (model-dostepu.md §6).
- Push do publicznej formatki = przez scrub-gate, nie przez ten runbook.

## 9. Zależności / poza zakresem v1

- Wybór hosta dla dedykowanego usera + PoC = po review (nie wykonywać przed).
- Warstwa retrieval/RAG (v2): index **per sektor-repo** (globalny index łączący sektory = obejście HARD-granicy, zakazane — model-dostepu.md §2).
