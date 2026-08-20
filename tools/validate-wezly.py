#!/usr/bin/env python3
# validate-wezly.py <dir> [<dir>...] - walidator wezlow wiedzy Szem wg docs/ontologia-wezlow.md.
#
# PO CO: repo glosi "enforced, not declared" dla DOSTEPU (RBAC testowany dwustronnie), ale warstwa
# METODY (ontologia wezlow) byla dotad 100%% konwencja. Ten walidator materializuje ten sam standard
# dla struktury wiedzy - egzekwuje to, co MECHANICZNIE sprawdzalne. Jakosci semantycznej (steelman
# naprawde >=3, czy antyteza to nie strawman, czy rama wlasciwa) NIE ocenia - to bramka 3 = człowiek
# (ontologia §4: self-reference wall, nieautomatyzowalne). Zero zaleznosci (tylko stdlib).
#
# Uzycie:  python3 tools/validate-wezly.py <katalog-z-wezlami> [...]
# Exit:    0 = czysto; N = liczba bledow (ERROR). WARN nie przerywa (heurystyki).
import sys, os, re

TYPES = {"cel","teza","antyteza","synteza","decyzja","ewaluacja","fakt",
         "architektura","eksperyment","runbook","reference","index"}
STATUSY = {"aktywny","obalony","zdemotowany","szkic","zamkniety"}
REQ = ["type","id","title","status","author","date","created_at"]  # §2

def parse_frontmatter(text):
    # zwraca (dict, body) - prosty subset YAML (key: value | key: [a, b] | key:\n  - a).
    if not text.startswith("---"):
        return None, text
    end = text.find("\n---", 3)
    if end == -1:
        return None, text
    fm_raw = text[3:end].strip("\n")
    body = text[end+4:]
    fm, cur_list_key = {}, None
    for line in fm_raw.split("\n"):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m_item = re.match(r"\s+-\s+(.*)$", line)
        if m_item and cur_list_key:
            fm[cur_list_key].append(m_item.group(1).strip().strip("'\""))
            continue
        m = re.match(r"([A-Za-z_][\w-]*):\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        if val == "":
            fm[key] = []; cur_list_key = key
        elif val.startswith("[") and val.endswith("]"):
            inner = val[1:-1].strip()
            fm[key] = [x.strip().strip("'\"") for x in inner.split(",") if x.strip()] if inner else []
            cur_list_key = None
        else:
            fm[key] = val.strip("'\""); cur_list_key = None
    return fm, body

def _selftest():
    # samo-weryfikacja tool-a (CI): fixture w pamieci -> tmp -> main() -> sprawdz wynik.
    import tempfile
    def nd(t,i,st="aktywny",par="[]",au="public",body="tresc"):
        a=f"author: {au}\n" if au else ""
        return f"---\ntype: {t}\nid: {i}\ntitle: T\nstatus: {st}\nparents: {par}\n{a}date: 2026-08-20\ncreated_at: 2026-08-20\n---\n{body}\n"
    valid={"cel.md":nd("cel","T-C1",body="kryterium falsyfikowalne X<5; zakres Y"),
           "teza.md":nd("teza","T-T1",par="[T-C1]"),
           "antyteza.md":nd("antyteza","T-AT1",par="[T-T1]",body="steelman 1;2;3"),
           "synteza.md":nd("synteza","T-S1",par="[T-T1, T-AT1]",body="kryterium obalenia: gdy m<prog")}
    invalid={"badtype.md":nd("xxx","T-X1"),"dupid.md":nd("fakt","T-C1",body="dowod:1"),
             "dangling.md":nd("fakt","T-D1",par="[NIEMA]",body="dowod:1"),
             "syntnokrit.md":nd("synteza","T-S2",par="[T-T1, T-AT1]",body="bez warunku"),
             "tezanoat.md":nd("teza","T-T9",par="[T-C1]"),
             "obalnoprov.md":nd("fakt","T-O1",st="obalony",body="plaski"),
             "nofield.md":nd("fakt","T-N1",au="",body="dowod:x")}
    def run(files):
        d=tempfile.mkdtemp()
        for n,c in files.items(): open(os.path.join(d,n),"w",encoding="utf-8").write(c)
        return main(["x",d])
    ok=run(valid); bad=run({**valid,**invalid})
    print(f"SELFTEST: valid->{ok} (exp 0) | valid+invalid->{bad} (exp 7)")
    return 0 if (ok==0 and bad==7) else 1

def main(argv):
    if argv[1:] == ["--selftest"]:
        return _selftest()
    dirs = argv[1:]
    if not dirs:
        print("uzycie: validate-wezly.py <katalog> [...]", file=sys.stderr); return 2
    nodes = {}      # id -> {file, fm, body}
    basenames = {}  # basename -> file
    errors, warns = [], []
    def err(f, msg): errors.append(f"ERROR {f}: {msg}")
    def warn(f, msg): warns.append(f"WARN  {f}: {msg}")

    files = []
    for d in dirs:
        for root, _, fs in os.walk(d):
            for fn in fs:
                if fn.endswith(".md"):
                    files.append(os.path.join(root, fn))

    # przebieg 1: parse + walidacja pojedynczego wezla
    for f in sorted(files):
        try:
            text = open(f, encoding="utf-8").read()
        except Exception as e:
            err(f, f"nie moge odczytac: {e}"); continue
        fm, body = parse_frontmatter(text)
        if fm is None:
            err(f, "brak frontmatter (--- ... ---)"); continue
        bn = os.path.basename(f)
        if bn in basenames:
            err(f, f"basename niepowtarzalny - kolizja z {basenames[bn]}")
        else:
            basenames[bn] = f
        for k in REQ:
            if k not in fm or fm[k] in ("", [], None):
                err(f, f"brak wymaganego pola frontmatter: {k}")
        t = fm.get("type")
        if t and t not in TYPES:
            err(f, f"nieznany type: {t}")
        st = fm.get("status")
        if st and st not in STATUSY:
            err(f, f"nieznany status: {st}")
        if "parents" not in fm:
            err(f, "brak pola parents (DAG; pusta lista dozwolona dla korzeni jak cel)")
        nid = fm.get("id")
        if nid:
            if nid in nodes:
                err(f, f"id niepowtarzalny - kolizja z {nodes[nid]['file']}")
            else:
                if not re.search(r"[-_/]", str(nid)):
                    warn(f, f"id nie wyglada na namespaced: {nid} (zalecane PROJ-T1)")
                nodes[nid] = {"file": f, "fm": fm, "body": body or ""}

    # przebieg 2: relacje miedzy wezlami (parents istnieja, DAG acykliczny, anty-wzorce §8)
    for nid, n in nodes.items():
        f, fm, body = n["file"], n["fm"], n["body"]
        parents = fm.get("parents") or []
        if isinstance(parents, str):
            parents = [parents]
        for p in parents:
            if p not in nodes:
                err(f, f"parents wskazuje na nieistniejacy id: {p}")
        t = fm.get("type")
        low = (body or "").lower()
        # §8: synteza bez kryterium obalenia = niesprawdzalna
        if t == "synteza":
            if not parents:
                err(f, "synteza bez parents (powinna laczyc teze + antyteze)")
            has_krit = ("kryterium_obalenia" in fm) or ("kryterium obalenia" in low)
            if not has_krit:
                err(f, "synteza bez KRYTERIUM OBALENIA (§8 anty-wzorzec: niesprawdzalna)")
        # §3/§8: teza bez realnej antytezy = ukryta decyzja
        if t == "teza":
            has_at = any(nn["fm"].get("type") == "antyteza" and nid in (nn["fm"].get("parents") or [])
                         for nn in nodes.values())
            if not has_at:
                err(f, f"teza bez antytezy wskazujacej na nia w parents (§3: to ukryta decyzja/ADR, nie teza)")
        # §6: obalony/zdemotowany bez proweniencji (co obalilo + dowod)
        if fm.get("status") in ("obalony","zdemotowany"):
            if not re.search(r"obali|proweniencj|dow[oó]d|\bbo\b", low):
                err(f, "status obalony/zdemotowany bez proweniencji (§6: co obalilo + dowod)")
        # heurystyki (WARN, nie blokuja - detekcja markerow jest miekka)
        if t == "eksperyment" and not re.search(r"baseline", low):
            warn(f, "eksperyment bez widocznego 'baseline' (§5: baseline + prog z gory)")
        if t == "cel" and not re.search(r"kryteri|falsyfik", low):
            warn(f, "cel bez widocznego kryterium falsyfikowalnego (§1)")

    for w in warns: print(w)
    for e in errors: print(e)
    print(f"--- wezly: {len(nodes)} | ERROR: {len(errors)} | WARN: {len(warns)}")
    return len(errors)

if __name__ == "__main__":
    sys.exit(main(sys.argv))
