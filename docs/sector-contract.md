# Kontrakt sektorów wiedzy (Szem)

> Mechanika klasyfikacji i opisu **sektorów wiedzy** w Szem. Sektor = jednostka wiedzy z określoną wrażliwością, zbiorem ról czytających i twardością granicy. Ten kontrakt jest uniwersalny (formatka); konkretne instancje wypełniają go swoimi sektorami.

## Po co
Twarda izolacja dostępu w Szem leży na poziomie **repo / remote / klucza per rola** (git nie ma per-path ACL). Żeby to zbudować, każdy sektor musi być opisany jednolicie — inaczej analizy z różnych źródeł nie składają się w spójny model dostępu (RBAC).

## Schemat opisu sektora
Każdy kandydat sektora deklaruje:

| pole | opis |
|---|---|
| `sektor` | stabilna nazwa (np. `frontend-render`, `api-schema`). **Sama nazwa nie może nieść treści wrażliwej.** |
| `wrazliwosc` | `PUBLIC` \| `PUBLIC-AFTER-SCRUB` \| `PRIVATE`. **Default = `PRIVATE`** (patrz DEFAULT-DENY). |
| `role-czytajace` | lista ról agentów z prawem READ (np. `agent-A`, `agent-integracja`). |
| `granica` | `HARD` (osobne repo/remote+klucz — sektor wrażliwy) \| `SOFT` (folder we wspólnym repo). Wstępna rekomendacja. |
| `zaleznosci` | lista sektorów, od których ten zależy (mapa dostępu; sektory cross-cutting = własny sektor, wiele ról). |

## Reguły wrażliwości
1. **DEFAULT-DENY.** Brak tagu lub niepewność → `PRIVATE` automatycznie. `PUBLIC` wymaga **uzasadnienia** (dlaczego publikowalne), nie odwrotnie. Asymetria: over-private jest tani, under-private nieodwracalny w historii gita.
2. **`PUBLIC-AFTER-SCRUB`** = treść zasadniczo publikowalna, ale opisana na przykładach wrażliwych (mechanika ilustrowana konkretną instancją). Flow: `PUBLIC-AFTER-SCRUB` → przepisanie/generalizacja → gate → `PUBLIC`. Bez tego stanu binarny tag wypycha takie sektory na `PUBLIC` i scrub się gubi.
3. **Tag = KANDYDAT, nie werdykt.** Werdykt wrażliwości = **niezależny gate** przy materializacji sektora (self-report bywa false-clean; źródło patrzące tylko na treść może nie zauważyć, że sama nazwa/kontekst niesie wrażliwą informację). Gate audytuje tagi **przed** założeniem sektor-repo, nie po.

## Materializacja
- `HARD` + `PRIVATE` → osobne repo/remote na hubie, klucz per rola (wzorzec deploy-key per rola).
- `SOFT` → folder we wspólnym repo instancji.
- `PUBLIC` (po gate) → repo publiczne (formatka).
- Granica IP = **granica repo**, nie folder.
