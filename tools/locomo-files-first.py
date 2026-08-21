#!/usr/bin/env python3
"""Files-first LoCoMo retrieval baseline.

Reads a local LoCoMo JSON file, materializes dialogue turns into temporary
Markdown files, and reports gold-evidence recall for full-context and a
lexical grep-style top-k retriever. It deliberately does not generate answers:
retrieval recall is not a LoCoMo QA score.
"""

import argparse
import json
import hashlib
import re
import shutil
import tempfile
from collections import Counter
from pathlib import Path

TOKEN_RE = re.compile(r"[\w']+", re.UNICODE)
SESSION_KEY_RE = re.compile(r"session_(\d+)$")
EVIDENCE_ID_RE = re.compile(r"D(\d+):(\d+)")


def tokens(text):
    return TOKEN_RE.findall(text.lower())


def session_numbers(conversation):
    return sorted(
        int(match.group(1))
        for key in conversation
        if (match := SESSION_KEY_RE.fullmatch(key))
    )
def sample_directory(workspace, sample_id):
    root = workspace.resolve()
    candidate = (root / str(sample_id)).resolve()
    if candidate.parent != root:
        raise ValueError(f"sample_id must be one safe path component: {sample_id!r}")
    return candidate




def materialize_sample(sample, workspace):
    """Return per-turn file documents preserving LoCoMo dia_id evidence IDs."""
    conversation = sample["conversation"]
    sample_dir = sample_directory(workspace, sample["sample_id"])
    documents = []
    for session_number in session_numbers(conversation):
        date = conversation.get(f"session_{session_number}_date_time", "")
        turns = conversation[f"session_{session_number}"]
        for turn_number, turn in enumerate(turns):
            dia_id = str(turn["dia_id"])
            content = f"DATE: {date}\nSPEAKER: {turn.get('speaker', '')}\nTEXT: {turn.get('text', '')}\n"
            if "blip_caption" in turn:
                content += f"IMAGE: {turn['blip_caption']}\n"
            filename = sample_dir / f"session_{session_number:03d}" / f"turn_{turn_number:05d}.md"
            filename.parent.mkdir(parents=True, exist_ok=True)
            filename.write_text(f"---\ndia_id: {dia_id}\n---\n{content}", encoding="utf-8")
            documents.append({
                "id": dia_id,
                "path": filename,
                "terms": Counter(tokens(filename.read_text(encoding="utf-8"))),
            })
    return documents


def evidence_references(question):
    evidence = question.get("evidence") or []
    if isinstance(evidence, str):
        evidence = [evidence]
    flattened = [
        str(value)
        for item in evidence
        for value in (item if isinstance(item, list) else [item])
    ]
    references = []
    malformed = []
    for value in flattened:
        references.extend(f"D{int(match.group(1))}:{int(match.group(2))}" for match in EVIDENCE_ID_RE.finditer(value))
        residue = EVIDENCE_ID_RE.sub("", value)
        malformed.extend(token for token in re.split(r"[\s,;]+", residue) if token)
    return references, malformed


def lexical_grep(question, documents, top_k):
    query = Counter(token for token in tokens(question) if len(token) > 2)
    scored = []
    for index, document in enumerate(documents):
        score = sum(weight * document["terms"][token] for token, weight in query.items())
        scored.append((score, -index, document["id"]))
    return [dia_id for _, _, dia_id in sorted(scored, reverse=True)[:top_k]]


def recall(expected, retrieved):
    retrieved_set = set(retrieved)
    return sum(item in retrieved_set for item in expected) / len(expected)
def mean_or_none(scores):
    return sum(scores) / len(scores) if scores else None




def evaluate(samples, workspace, top_k):
    full_scores = []
    lexical_scores = []
    questions = 0
    questions_without_evidence = 0
    malformed_references = 0
    unresolved_references = 0
    valid_full_scores = []
    valid_lexical_scores = []
    for sample in samples:
        documents = materialize_sample(sample, workspace)
        full_context = [document["id"] for document in documents]
        full_context_set = set(full_context)
        for question in sample.get("qa", []):
            questions += 1
            expected, malformed = evidence_references(question)
            malformed_references += len(malformed)
            if not expected:
                questions_without_evidence += 1
                continue
            resolved = [reference for reference in expected if reference in full_context_set]
            unresolved_references += len(expected) - len(resolved)
            retrieved = lexical_grep(question["question"], documents, top_k)
            full_scores.append(recall(expected, full_context))
            lexical_scores.append(recall(expected, retrieved))
            if resolved:
                valid_full_scores.append(recall(resolved, full_context))
                valid_lexical_scores.append(recall(resolved, retrieved))
    if not full_scores:
        raise ValueError("LoCoMo input nie zawiera pytań QA z parseable evidence.")
    return {
        "samples": len(samples),
        "questions": questions,
        "questions_with_evidence": len(full_scores),
        "questions_with_resolved_evidence": len(valid_full_scores),
        "questions_without_parseable_evidence": questions_without_evidence,
        "unparseable_evidence_tokens": malformed_references,
        "unresolved_evidence_ids": unresolved_references,
        "full_context_evidence_recall": mean_or_none(full_scores),
        "lexical_grep_evidence_recall": mean_or_none(lexical_scores),
        "full_context_valid_evidence_recall": mean_or_none(valid_full_scores),
        "lexical_grep_valid_evidence_recall": mean_or_none(valid_lexical_scores),
        "top_k": top_k,
    }


def main():
    parser = argparse.ArgumentParser(description="Files-first LoCoMo retrieval baseline; reports evidence recall, not QA score.")
    parser.add_argument("--data-file", required=True, type=Path, help="Local LoCoMo JSON; never commit this NC dataset to the repository.")
    parser.add_argument("--top-k", default=10, type=int, help="Lexical grep-style retrieval depth.")
    parser.add_argument("--workspace", type=Path, help="Optional persistent workspace; omitted means a temporary directory is removed after the run.")
    parser.add_argument("--output", type=Path, help="Optional JSON result path.")
    args = parser.parse_args()
    if args.top_k < 1:
        parser.error("--top-k musi być dodatnie.")
    if not args.data_file.is_file():
        parser.error(f"--data-file nie istnieje albo nie jest plikiem: {args.data_file}")

    raw = args.data_file.read_bytes()
    samples = json.loads(raw)
    if not isinstance(samples, list):
        raise ValueError("LoCoMo input musi być listą samples.")

    temporary = args.workspace is None
    workspace = args.workspace if args.workspace else Path(tempfile.mkdtemp(prefix="szem-locomo-"))
    try:
        workspace.mkdir(parents=True, exist_ok=True)
        result = evaluate(samples, workspace, args.top_k)
        result.update({
            "data_sha256": hashlib.sha256(raw).hexdigest(),
            "workspace_persistent": not temporary,
            "metric_scope": "gold evidence recall only; not LoCoMo QA F1/EM",
        })
        rendered = json.dumps(result, indent=2, sort_keys=True)
        if args.output:
            args.output.write_text(f"{rendered}\n", encoding="utf-8")
        print(rendered)
    finally:
        if temporary:
            shutil.rmtree(workspace, ignore_errors=True)


if __name__ == "__main__":
    main()
