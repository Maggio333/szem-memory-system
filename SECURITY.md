# Security

## Model zaufania (co ten projekt gwarantuje)
- **Izolacja sektorów wiedzy jest twarda tam, gdzie stoi na kluczach:** sektor = osobne repo, dostęp = klucz roli w gitolite (RW/R wg matrycy). Test dwustronny (własny sektor `[OK]`, cudzy `[DENY]`) jest częścią bootstrapa — instancja bez przechodzącego testu nie jest postawiona.
- **Localhost-first:** świeża instancja słucha tylko lokalnie. Ekspozycja w LAN/WAN to osobna, świadoma decyzja operatora poprzedzona threat-review — nigdy default.
- **TOFU z persystencją:** `ssh-config` workspace'ów pinuje hosta w `known_hosts` per-workspace (`accept-new` bez utrwalenia to TOFU bez T).

## Zasady dot. sekretów (twarde)
- **Żadnych sekretów w żadnym repo** — także prywatnym: klucze prywatne ról żyją wyłącznie na maszynie agenta (perms 600), poza gitem.
- Repo przenosi wyłącznie **fingerprinty** (kotwica integralności) i **wskaźniki ścieżek**.
- Manifest instancji jest source-owany jako root — trzymaj poza publiczną formatką, w zaufanym miejscu.
- Rewokacja dostępu = usunięcie klucza roli z gitolite: O(1), bez rewritu historii.

## Zgłaszanie podatności
Preferowane: **GitHub Security Advisories** (Report a vulnerability) tego repozytorium.
Alternatywnie: Issue z minimalnym opisem wpływu (bez exploita w treści publicznej) — poprosimy o szczegóły kanałem prywatnym.
Prosimy o: wersję/commit, kroki odtworzenia, ocenę wpływu. Odpowiadamy possibly-fast; poprawki bezpieczeństwa mają pierwszeństwo przed feature'ami.

## Zakres
Ten dokument dotyczy **formatki** (mechanika, narzędzia, szablony). Bezpieczeństwo konkretnej *instancji* (klucze, ekspozycja, treść sektorów) jest odpowiedzialnością jej operatora — formatka daje mechanizmy (RBAC per rolę, test dwustronny, localhost-first, rejestr fingerprintów), nie przejmuje odpowiedzialności za ich użycie.
