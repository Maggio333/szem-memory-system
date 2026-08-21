#!/usr/bin/env python3
"""Generate and validate the synthetic Szem 2x2 agent benchmark.

The generated pack is intentionally outside the repository. It contains a runtime
pack and a separate oracle; an executor must never mount the oracle for agents.
No command here runs an agent trial.
"""
import argparse
import hashlib
import json
import random
import re
import shutil
import sys
from collections import Counter
from pathlib import Path

VERSION = "E-AGENT-2X2/v1"
SCHEMAS = ("E1", "E2", "H1", "H2", "H3")
HARD_SCHEMAS = {"H1", "H2", "H3"}
WORDS = (
    "amber", "basalt", "cedar", "dune", "ember", "fable", "grove", "harbor",
    "iris", "juniper", "keystone", "lagoon", "mesa", "north", "onyx", "prairie",
    "quartz", "raven", "saffron", "tundra", "umber", "violet", "willow", "zinc",
)


def canonical_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def sha256_bytes(value):
    return hashlib.sha256(value).hexdigest()


def digest_words(seed, item_id, count):
    values, nonce = [], 0
    while len(values) < count:
        digest = hashlib.sha256(f"{VERSION}:{seed}:{item_id}:{nonce}".encode("utf-8")).digest()
        for byte in digest:
            value = WORDS[byte % len(WORDS)]
            if value not in values:
                values.append(value)
                if len(values) == count:
                    return values
        nonce += 1


def normalize(value):
    return "".join(char.lower() for char in value if char.isalnum())


def evidence_span(card_id, text, value):
    start = text.index(value)
    end = start + len(value)
    return {"card_id": card_id, "start": start, "end": end, "sha256": sha256_bytes(text[start:end].encode("utf-8"))}


def card(item_id, number, text):
    return {"id": f"{item_id}-C{number}", "text": text}


def make_e1(seed, item_id):
    label, value = digest_words(seed, item_id, 2)
    source = card(item_id, 1, f"Registry {label} stores the marker {value}.")
    return [source], f"Which marker is stored by registry {label}?", value, [evidence_span(source["id"], source["text"], value)]


def make_e2(seed, item_id):
    mode, ceiling = digest_words(seed, item_id, 2)
    first = card(item_id, 1, f"The earlier decision selects mode {mode}.")
    second = card(item_id, 2, f"The later constraint sets the ceiling to {ceiling}.")
    answer = f"mode={mode}; ceiling={ceiling}"
    return [first, second], "State the current mode and ceiling after the recorded change.", answer, [
        evidence_span(first["id"], first["text"], mode),
        evidence_span(second["id"], second["text"], ceiling),
    ]


def make_h1(seed, item_id):
    adopt, support, reject, *rest = digest_words(seed, item_id, 6)
    cards = [
        card(item_id, 1, f"Source A supports option {adopt}."),
        card(item_id, 2, f"Source B supplies constraint {support}."),
        card(item_id, 3, f"Source C rules out option {reject}."),
        card(item_id, 4, f"Source D gives unrelated context {rest[0]}."),
        card(item_id, 5, f"Source E records audit tag {rest[1]}."),
        card(item_id, 6, f"Source F records fallback tag {rest[2]}."),
    ]
    answer = f"adopt={adopt}; support={support}; reject={reject}"
    return cards, "Synthesize the supported decision with its constraint and rejected option.", answer, [
        evidence_span(cards[0]["id"], cards[0]["text"], adopt),
        evidence_span(cards[1]["id"], cards[1]["text"], support),
        evidence_span(cards[2]["id"], cards[2]["text"], reject),
    ]


def make_h2(seed, item_id):
    phase, guard, owner, *rest = digest_words(seed, item_id, 5)
    cards = [
        card(item_id, 1, f"Plan phase is {phase}."),
        card(item_id, 2, f"Required guard is {guard}."),
        card(item_id, 3, f"Assigned owner role is {owner}."),
        card(item_id, 4, f"Archive label is {rest[0]}."),
        card(item_id, 5, f"Review label is {rest[1]}."),
    ]
    answer = f"phase={phase}; guard={guard}; owner={owner}"
    return cards, "Produce the plan satisfying the recorded phase, guard, and owner constraints.", answer, [
        evidence_span(cards[0]["id"], cards[0]["text"], phase),
        evidence_span(cards[1]["id"], cards[1]["text"], guard),
        evidence_span(cards[2]["id"], cards[2]["text"], owner),
    ]


def make_h3(seed, item_id):
    rejected, repair, reason, *rest = digest_words(seed, item_id, 5)
    cards = [
        card(item_id, 1, f"The earlier proposal chose {rejected}."),
        card(item_id, 2, f"A later review rejects {rejected} because of {reason}."),
        card(item_id, 3, f"The corrective action is {repair}."),
        card(item_id, 4, f"Audit note is {rest[0]}."),
        card(item_id, 5, f"Recovery tag is {rest[1]}."),
    ]
    answer = f"reject={rejected}; reason={reason}; repair={repair}"
    return cards, "Recover from the invalid proposal: state the rejection, reason, and corrective action.", answer, [
        evidence_span(cards[1]["id"], cards[1]["text"], rejected),
        evidence_span(cards[1]["id"], cards[1]["text"], reason),
        evidence_span(cards[2]["id"], cards[2]["text"], repair),
    ]


BUILDERS = {"E1": make_e1, "E2": make_e2, "H1": make_h1, "H2": make_h2, "H3": make_h3}


def build_pack(seed):
    runtime_items, oracle_items = [], []
    for schema in SCHEMAS:
        for ordinal in range(1, 21):
            item_id = f"{schema}-{ordinal:03d}"
            cards, question, answer, spans = BUILDERS[schema](seed, item_id)
            runtime_items.append({
                "id": item_id,
                "schema": schema,
                "stratum": "hard" if schema in HARD_SCHEMAS else "easy",
                "memory_required": True,
                "prior_session_cards": cards,
                "current_task": {"id": item_id, "question": question},
                "allowed_evidence_spans": spans,
            })
            oracle_items.append({
                "id": item_id,
                "answer_projection": answer,
                "required_evidence_ids": [span["card_id"] for span in spans],
                "scoring": "exact" if schema in {"E1", "E2"} else "blind-binary-rubric",
            })
    return {"version": VERSION, "items": runtime_items}, {"version": VERSION, "seed": seed, "items": oracle_items}


def write_json(path, value):
    path.write_bytes(canonical_bytes(value))


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def validate_pack(root):
    root = Path(root)
    manifest_path, runtime_path, oracle_path, provenance_path = (
        root / "pack-manifest.json", root / "task-pack.json", root / "oracle.json", root / "verifier-provenance.json"
    )
    for path in (manifest_path, runtime_path, oracle_path, provenance_path):
        if not path.is_file():
            raise ValueError(f"missing required file: {path.name}")
    manifest, runtime, oracle, provenance = (
        read_json(manifest_path), read_json(runtime_path), read_json(oracle_path), read_json(provenance_path)
    )
    if manifest.get("version") != VERSION or runtime.get("version") != VERSION or oracle.get("version") != VERSION:
        raise ValueError("unsupported or inconsistent pack version")
    for path, key in (
        (runtime_path, "task_pack_sha256"), (oracle_path, "oracle_sha256"), (provenance_path, "verifier_provenance_sha256")
    ):
        if sha256_bytes(path.read_bytes()) != manifest.get(key):
            raise ValueError(f"hash mismatch for {path.name}")
    if sha256_bytes(str(provenance.get("seed")).encode("utf-8")) != manifest.get("seed_commitment_sha256"):
        raise ValueError("seed commitment mismatch")
    if "seed" in runtime:
        raise ValueError("runtime task pack must not disclose the generator seed")
    items, answers = runtime.get("items", []), oracle.get("items", [])
    if len(items) != 100 or len(answers) != 100:
        raise ValueError("pack must contain exactly 100 runtime items and 100 oracle entries")
    ids = [item.get("id") for item in items]
    if len(set(ids)) != 100 or set(ids) != {answer.get("id") for answer in answers}:
        raise ValueError("runtime and oracle item IDs must be unique and identical")
    if Counter(item.get("schema") for item in items) != Counter({schema: 20 for schema in SCHEMAS}):
        raise ValueError("pack must contain 20 items for every preregistered schema")
    answers_by_id = {answer["id"]: answer for answer in answers}
    for item in items:
        if item.get("memory_required") is not True:
            raise ValueError(f"{item['id']}: memory_required must be predeclared true")
        answer = answers_by_id[item["id"]]
        prompt = item.get("current_task", {}).get("question", "")
        if normalize(answer["answer_projection"]) in normalize(prompt):
            raise ValueError(f"{item['id']}: answer projection leaked into current prompt")
        cards = {source["id"]: source["text"] for source in item.get("prior_session_cards", [])}
        for span in item.get("allowed_evidence_spans", []):
            text = cards.get(span.get("card_id"), "")
            start, end = span.get("start"), span.get("end")
            if not isinstance(start, int) or not isinstance(end, int) or not (0 <= start < end <= len(text)):
                raise ValueError(f"{item['id']}: invalid evidence span")
            if sha256_bytes(text[start:end].encode("utf-8")) != span.get("sha256"):
                raise ValueError(f"{item['id']}: evidence span hash mismatch")
        if item["schema"] in {"H1", "H3"}:
            projected = normalize(answer["answer_projection"])
            if any(projected in normalize(text) for text in cards.values()):
                raise ValueError(f"{item['id']}: a single source card contains the complete answer projection")
    return manifest


def generate(args):
    output = Path(args.output)
    if output.exists():
        raise ValueError("output directory already exists; generation is write-once")
    runtime, oracle = build_pack(args.seed)
    output.mkdir(parents=True)
    provenance = {"version": VERSION, "seed": args.seed}
    write_json(output / "task-pack.json", runtime)
    write_json(output / "oracle.json", oracle)
    write_json(output / "verifier-provenance.json", provenance)
    manifest = {
        "version": VERSION,
        "seed_commitment_sha256": sha256_bytes(str(args.seed).encode("utf-8")),
        "task_pack_sha256": sha256_bytes((output / "task-pack.json").read_bytes()),
        "oracle_sha256": sha256_bytes((output / "oracle.json").read_bytes()),
        "verifier_provenance_sha256": sha256_bytes((output / "verifier-provenance.json").read_bytes()),
        "runtime_files": ["task-pack.json"],
        "verifier_only_files": ["oracle.json", "verifier-provenance.json"],
        "oracle_must_not_mount": True,
    }
    write_json(output / "pack-manifest.json", manifest)
    validate_pack(output)
    print(json.dumps(manifest, ensure_ascii=False, sort_keys=True))


def hex_argument(value, name, length, kind):
    if len(value) != length or any(char not in "0123456789abcdef" for char in value):
        raise ValueError(f"{name} must be a lowercase {length}-character {kind} hex digest")
    return value


def prepare(args):
    pack = validate_pack(args.pack)
    output = Path(args.output)
    if output.exists():
        raise ValueError("output file already exists; manifest is write-once")
    protocol_commit = hex_argument(args.protocol_commit, "protocol_commit", 40, "Git SHA-1")
    runner_sha = hex_argument(args.runner_sha, "runner_sha", 64, "SHA-256")
    if not re.fullmatch(r"\d+\.\d+\.\d+", args.omp_version):
        raise ValueError("omp_version must be a semantic version such as 17.3.5")
    schedule = [{"item_id": item_id, "arm": arm} for item_id in [f"{schema}-{ordinal:03d}" for schema in SCHEMAS for ordinal in range(1, 21)] for arm in ("S0", "S1", "T0", "T1")]
    random.Random(args.schedule_seed).shuffle(schedule)
    manifest = {
        "version": VERSION,
        "protocol_commit": protocol_commit,
        "pack_manifest_sha256": sha256_bytes((Path(args.pack) / "pack-manifest.json").read_bytes()),
        "task_pack_sha256": pack["task_pack_sha256"],
        "oracle_sha256": pack["oracle_sha256"],
        "oracle_must_not_mount": True,
        "arms": {
            "S0": {"agents": ["solo"], "memory": "off"},
            "S1": {"agents": ["solo"], "memory": "Szem files-first/retrieval"},
            "T0": {"agents": ["coordinator", "analyst", "verifier"], "memory": "off"},
            "T1": {"agents": ["coordinator", "analyst", "verifier"], "memory": "Szem files-first/retrieval"},
        },
        "runtime": {
            "kind": "remote-provider",
            "provider": "anthropic",
            "model": "claude-opus-4-8",
            "selector": "anthropic/claude-opus-4-8",
            "omp_version": args.omp_version,
            "thinking": "high",
            "temperature": 0,
            "retry": {"model_fallback": False, "per_arm": False},
            "reproducibility_limit": "The provider model identifier is recorded, but it is not an immutable model artifact; record request and response metadata for every arm.",
        },
        "runner_sha256": runner_sha,
        "decoding": {"temperature": 0, "thinking": "high"},
        "budgets": {"input_tokens": args.input_tokens, "output_tokens": args.output_tokens, "tool_calls": args.tool_calls, "wall_seconds": args.wall_seconds},
        "trials_per_item_arm": 1,
        "retry_policy": "infrastructure failure before answer reruns all four arms for the item",
        "schedule_seed": args.schedule_seed,
        "schedule": schedule,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    write_json(output, manifest)
    print(json.dumps({"manifest": str(output), "runs": len(schedule)}, ensure_ascii=False, sort_keys=True))


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    gen = sub.add_parser("generate", help="write a deterministic synthetic pack")
    gen.add_argument("--output", required=True)
    gen.add_argument("--seed", type=int, required=True)
    gen.set_defaults(func=generate)
    check = sub.add_parser("validate", help="validate a generated pack")
    check.add_argument("--pack", required=True)
    check.set_defaults(func=lambda args: print(json.dumps(validate_pack(args.pack), ensure_ascii=False, sort_keys=True)))
    prep = sub.add_parser("prepare", help="write a fixed 2x2 execution manifest without running agents")
    prep.add_argument("--pack", required=True)
    prep.add_argument("--output", required=True)
    prep.add_argument("--protocol-commit", required=True)
    prep.add_argument("--omp-version", required=True)
    prep.add_argument("--runner-sha", required=True)
    prep.add_argument("--input-tokens", type=int, required=True)
    prep.add_argument("--output-tokens", type=int, required=True)
    prep.add_argument("--tool-calls", type=int, required=True)
    prep.add_argument("--wall-seconds", type=int, required=True)
    prep.add_argument("--schedule-seed", type=int, default=20260821)
    prep.set_defaults(func=prepare)
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (ValueError, OSError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(2)
