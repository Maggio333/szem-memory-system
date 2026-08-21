#!/usr/bin/env python3
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("locomo-files-first.py")


class LoCoMoFilesFirstTest(unittest.TestCase):
    def test_full_context_and_lexical_recall(self):
        fixture = [{
            "sample_id": "synthetic-1",
            "conversation": {
                "session_1_date_time": "2026-01-01",
                "session_1": [
                    {"dia_id": "D1:1", "speaker": "Alex", "text": "Alex met Taylor at the library."},
                    {"dia_id": "D1:2", "speaker": "Taylor", "text": "Taylor brought a blue notebook."},
                ],
            },
            "qa": [
                {"question": "Where did Alex meet Taylor?", "answer": "library", "category": 3, "evidence": ["D1:1"]},
                {"question": "What did Taylor bring?", "answer": "blue notebook", "category": 1, "evidence": ["D1:2"]},
                {"question": "What was never mentioned?", "answer": "No information available", "category": 5, "evidence": []},
            ],
        }]
        with tempfile.TemporaryDirectory() as directory:
            data_file = Path(directory) / "locomo.json"
            data_file.write_text(json.dumps(fixture), encoding="utf-8")
            completed = subprocess.run(
                [sys.executable, str(SCRIPT), "--data-file", str(data_file), "--top-k", "1"],
                check=True,
                text=True,
                capture_output=True,
            )
        result = json.loads(completed.stdout)
        self.assertEqual(result["questions"], 3)
        self.assertEqual(result["questions_with_evidence"], 2)
        self.assertEqual(result["questions_with_resolved_evidence"], 2)
        self.assertEqual(result["questions_without_parseable_evidence"], 1)
        self.assertEqual(result["unparseable_evidence_tokens"], 0)
        self.assertEqual(result["unresolved_evidence_ids"], 0)
        self.assertEqual(result["full_context_evidence_recall"], 1.0)
        self.assertEqual(result["lexical_grep_evidence_recall"], 1.0)
        self.assertEqual(result["full_context_valid_evidence_recall"], 1.0)
        self.assertEqual(result["lexical_grep_valid_evidence_recall"], 1.0)
        self.assertFalse(result["workspace_persistent"])
        self.assertEqual(result["metric_scope"], "gold evidence recall only; not LoCoMo QA F1/EM")

    def test_evidence_delimiters_and_malformed_tokens_are_reported(self):
        fixture = [{
            "sample_id": "synthetic-2",
            "conversation": {
                "session_1_date_time": "2026-01-01",
                "session_1": [
                    {"dia_id": "D1:1", "speaker": "Alex", "text": "The library has a notebook."},
                    {"dia_id": "D1:2", "speaker": "Taylor", "text": "The notebook is blue."},
                ],
            },
            "qa": [{
                "question": "Which notebook was at the library?",
                "answer": "blue notebook",
                "category": 3,
                "evidence": ["D1:1; D1:2", "D2:9", "D:3:4"],
            }],
        }]
        with tempfile.TemporaryDirectory() as directory:
            data_file = Path(directory) / "locomo.json"
            data_file.write_text(json.dumps(fixture), encoding="utf-8")
            completed = subprocess.run(
                [sys.executable, str(SCRIPT), "--data-file", str(data_file), "--top-k", "2"],
                check=True,
                text=True,
                capture_output=True,
            )
        result = json.loads(completed.stdout)
        self.assertEqual(result["questions_with_evidence"], 1)
        self.assertEqual(result["unparseable_evidence_tokens"], 1)
        self.assertEqual(result["unresolved_evidence_ids"], 1)
        self.assertAlmostEqual(result["full_context_evidence_recall"], 2 / 3)
        self.assertAlmostEqual(result["lexical_grep_evidence_recall"], 2 / 3)
        self.assertEqual(result["full_context_valid_evidence_recall"], 1.0)
        self.assertEqual(result["lexical_grep_valid_evidence_recall"], 1.0)

    def test_all_unresolved_evidence_reports_null_valid_only_metrics(self):
        fixture = [{
            "sample_id": "synthetic-3",
            "conversation": {
                "session_1_date_time": "2026-01-01",
                "session_1": [{"dia_id": "D1:1", "speaker": "Alex", "text": "The library is open."}],
            },
            "qa": [{"question": "Where is the missing evidence?", "answer": "", "category": 3, "evidence": ["D2:9"]}],
        }]
        with tempfile.TemporaryDirectory() as directory:
            data_file = Path(directory) / "locomo.json"
            data_file.write_text(json.dumps(fixture), encoding="utf-8")
            completed = subprocess.run(
                [sys.executable, str(SCRIPT), "--data-file", str(data_file), "--top-k", "1"],
                check=True,
                text=True,
                capture_output=True,
            )
        result = json.loads(completed.stdout)
        self.assertEqual(result["questions_with_resolved_evidence"], 0)
        self.assertEqual(result["unresolved_evidence_ids"], 1)
        self.assertEqual(result["full_context_evidence_recall"], 0.0)
        self.assertEqual(result["lexical_grep_evidence_recall"], 0.0)
        self.assertIsNone(result["full_context_valid_evidence_recall"])
        self.assertIsNone(result["lexical_grep_valid_evidence_recall"])

    def test_path_traversal_sample_id_is_rejected_before_writing(self):
        fixture = [{
            "sample_id": "../escape",
            "conversation": {
                "session_1_date_time": "2026-01-01",
                "session_1": [{"dia_id": "D1:1", "speaker": "Alex", "text": "Never write outside workspace."}],
            },
            "qa": [],
        }]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            data_file = root / "locomo.json"
            workspace = root / "workspace"
            data_file.write_text(json.dumps(fixture), encoding="utf-8")
            completed = subprocess.run(
                [sys.executable, str(SCRIPT), "--data-file", str(data_file), "--workspace", str(workspace)],
                check=False,
                text=True,
                capture_output=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("sample_id must be one safe path component", completed.stderr)
            self.assertFalse((root / "escape").exists())


if __name__ == "__main__":
    unittest.main()
