# Współtworzenie Szem

Dzięki za zainteresowanie. **Szem** to *formatka* — substrat pamięci i metody pod systemy agentyczne (domyślny harness: [Omp / oh-my-pi](https://github.com/can1357/oh-my-pi), przepinany przez warstwę adaptera). Wkład przyjmujemy przez GitHub: **Issues** (zgłoszenia i propozycje) oraz **Pull Requesty**.

## Zanim zaczniesz

- Przeczytaj [`QUICKSTART.md`](QUICKSTART.md) (od `git clone` do działającej instancji) i [`README.md`](README.md) (czym jest formatka, model dostępu).
- Mechanika, na której stoimy: `docs/` (model dostępu, sector-contract, ontologia węzłów, enforcement-runbook), `skills/` (metoda + dziennik), `templates/` (typy węzłów, matryca RBAC, struktura instancji).

## Zgłoszenia (Issues)

- **Bug:** co zrobiłeś, co się stało, co powinno; wersje (`omp --version`, `bd --version`, dystrybucja WSL/OS); minimalny sposób odtworzenia.
- **Propozycja:** problem *przed* rozwiązaniem. Zmiany w metodzie/węzłach opisuj dialektycznie (Cel → Teza ↔ Antyteza → Synteza z **kryterium obalenia** → Decyzja/ADR → Ewaluacja) — to rdzeń formatki, nie ozdoba.

## Pull Requesty

1. Zrób fork i gałąź tematyczną (`fix/...`, `docs/...`, `feat/...`).
2. Jeden PR = jeden temat. Krótki commit-subject: *co i po co*.
3. Twierdzenie z metryką popieraj **dowodem** (wynik komendy, `plik:linia`), nie „na oko".
4. Zmiana logiki/kontraktu → dopisz test lub jawny scenariusz weryfikacji; dokumentację i przykłady trzymaj w zgodzie ze zmianą.
5. Nowy harness/adapter → spełnij kontrakt z [`docs/adapter-omp.md`](docs/adapter-omp.md) (§2). Domyślna ścieżka Omp i jej uznanie zostają; przepinalność ≠ usuwanie wymagań aktualnego domyślnego harnessu.

## Zasady twarde

- **Zero sekretów.** Żadnych kluczy, tokenów, haseł ani danych konkretnej instancji (nazwy projektów/osób, ścieżki bezwzględne, adresy) w commitach, PR-ach ani Issues. Repo jest publiczne i *clean-from-first-commit* — nic wrażliwego nie może wpaść nawet przejściowo. Materiał wchodzi tylko: napisany od zera jako publiczny albo przepuszczony przez scrub.
- **Granica IP = granica repo.** Tu żyje wyłącznie generyczna formatka. Treść prywatnej instancji (agenci, wiedza konkretnych aplikacji) należy do osobnego, prywatnego repo, które tylko *importuje* tę formatkę.
- **Podatności** zgłaszaj zgodnie z [`SECURITY.md`](SECURITY.md), nie jako publiczny Issue.

## Ekosystem Omp

Szem stoi na ekosystemie Omp. Poprawki i integracje dotyczące samego harnessu chętnie kierujemy z powrotem do [projektu Omp](https://github.com/can1357/oh-my-pi) — wspieramy ekosystem, na którym budujemy.

## Licencja wkładu

Zgłaszając PR zgadzasz się, że Twój wkład będzie objęty licencją repozytorium (patrz `LICENSE`).
