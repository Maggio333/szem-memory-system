# Model dostępu — RBAC sektorów wiedzy

> Status: **aktywny** (zmergowany do main; enforcement zweryfikowany dwustronnie w bootstrapie). Konsoliduje ustalenia zespołu; zero nowych decyzji.

Szem dzieli wiedzę na **sektory**, a dostęp agenta do sektora wynika z jego **roli**. Kluczowa zasada: izolacja ma być **egzekwowana technicznie**, nie deklarowana — konwencja, którą da się ominąć błędem albo prompt-injection, nie jest granicą.

## 1. Dwa poziomy granic

| Poziom | Mechanizm | Gwarancja | Kiedy |
|---|---|---|---|
| **HARD** | osobne repo/remote + własny klucz (np. deploy-key/SSH per rola) | agent bez klucza **fizycznie nie widzi** sektora | sektory wrażliwe, granica publiczne↔prywatne |
| **SOFT** | folder we wspólnym repo + konwencja/skill | honor-system; omijalny | wiedza wspólna o niskiej wrażliwości |

Fakt techniczny, z którego to wynika: **git nie ma per-path ACL** — kto ma repo, ma wszystko (z całą historią). Twarda granica może więc leżeć wyłącznie na poziomie *repo/remote/klucza*, nigdy folderu.

## 2. Kompozycja: meta-repo

Jeden punkt wejścia („jedno repo" mentalnie) = **meta-repo**, które referencjami/submodułami komponuje sektor-repa. Rola agenta = zbiór kluczy do sektor-repo, które wolno mu czytać. Meta-repo nie zawiera treści sektorów wrażliwych — tylko wskazania.

Własności:
- zero nowej technologii (standardowy git + klucze; wzorzec zwalidowany produkcyjnie: konto deploy-only z forced-command i kluczem per osoba);
- rewokacja = usunięcie jednego klucza;
- forward-compatible z retrieval (v2): index buduje się **per sektor-repo**, więc RAG nie omija granic (globalny index po sektorach = obejście HARD-granicy; zakazany).

v1 formatki = **files-first** (agent czyta pliki przez git). Warstwa retrieval — dopiero gdy skala wymusi, wg reguły wyżej.

## 3. Taksonomia wrażliwości sektora

| Tag | Znaczenie | Droga do publikacji |
|---|---|---|
| `PUBLIC` | pisany od zera jako publiczny | gate → publikacja |
| `PUBLIC-AFTER-SCRUB` | treść publikowalna, ale ilustrowana materiałem prywatnym | przepisanie/generalizacja → gate → publikacja |
| `PRIVATE` | wiedza instancji (aplikacje, osoby, infrastruktura, incydenty) | nie publikuje się; żyje w prywatnym sektor-repo |

Reguły:
- **Default-deny**: brak tagu albo niepewność ⇒ `PRIVATE`. To `PUBLIC` wymaga uzasadnienia, nie odwrotnie (asymetria: nadmierna prywatność jest tania; wyciek do historii gita jest nieodwracalny).
- Tag nadany przy analizie (np. przez scouta) jest **kandydatem** — werdykt wydaje niezależny gate przed materializacją sektora. Self-report bywa false-clean; audyt patrzy też na to, czego autor tagu nie widzi (np. sama *nazwa* sektora może nieść prywatną informację).

## 4. Scrub-gate (przepływ publikacji)

1. **Clean-from-first-commit**: do strefy publicznej nic nie wchodzi „przejściowo" — git pamięta całą historię; sanacja po fakcie = rewrite + force-push. Materiał wchodzi wyłącznie (a) pisany od zera jako publiczny, (b) po przejściu gate.
2. **Gate = niezależna para oczu**, nie autor zmiany. Zakres: nazwy własne instancji, osoby, ścieżki bezwzględne, sekrety/klucze, szczegóły architektury prywatnej, przykłady zdradzające kontekst.
3. Gate działa **per commit przed pushem** na remote publiczny; zielony wynik jest warunkiem pusha, nie opinią.
4. `.gitignore` strefy publicznej blokuje klasy plików sekretów (`*.key`, `*.pem`, klucze SSH, `.env*`) — to backstop, nie substytut gate'u.

## 5. Granica publiczne ↔ prywatne = granica repo

Formatka (to repo) jest publiczna i **generyczna**: zero treści instancji. Instancja prywatna (konkretni agenci, ich beady, wiedza aplikacji) to **osobne repo**, które formatkę *importuje*. Ta sama zasada rekurencyjnie: każda kolejna instancja = osobne repo z własnymi kluczami.

## 6. Punkt rozszerzenia: Emet / Met

Para prymitywów bezpieczeństwa dystrybuowalnej instancji (nazewnictwo z mitu golema):
- **Emet** (prawda) = stan *integrity-gate-passed*: instancja działa tylko na wiedzy, która przeszła gate (podpis/suma kontrolna sektorów).
- **Met** (śmierć) = czysty deaktywator: odebranie kluczy sektorowych + zatrzymanie agentów instancji; rewokacja per-klucz czyni to operacją O(liczba ról).

Formatka rezerwuje to jako punkt rozszerzenia; implementacja poza zakresem v1.

## 7. Anty-wzorce (zakazane)

- Sektor wrażliwy jako folder we wspólnym repo („będziemy pamiętać, żeby nie czytać").
- Globalny embedding-index łączący sektory o różnych granicach.
- Współdzielenie jednego klucza przez wiele ról/osób (zero rozliczalności i rewokacji).
- „Wrzucimy, potem wyczyścimy" do strefy publicznej.
- Gate wykonywany przez autora zmiany.
