#!/usr/bin/env python3
"""Contract tests for tools/agent-benchmark.py; uses only the Python standard library."""
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCRIPT = ROOT / "agent-benchmark.py"
SHA_A = "a" * 64
SHA_B = "b" * 64
GIT_A = "c" * 40


def run(*args, ok=True):
    result = subprocess.run([sys.executable, str(SCRIPT), *args], text=True, capture_output=True)
    if result.returncode != (0 if ok else 2):
        raise AssertionError(f"unexpected exit {result.returncode}: stdout={result.stdout!r} stderr={result.stderr!r}")
    return result


def tree_bytes(root):
    return {path.relative_to(root).as_posix(): path.read_bytes() for path in sorted(root.rglob("*")) if path.is_file()}


def main():
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        first, second = root / "first", root / "second"
        run("generate", "--output", str(first), "--seed", "731")
        run("generate", "--output", str(second), "--seed", "731")
        assert tree_bytes(first) == tree_bytes(second), "same seed must produce byte-identical packs"
        run("validate", "--pack", str(first))

        pack = json.loads((first / "task-pack.json").read_text(encoding="utf-8"))
        oracle = json.loads((first / "oracle.json").read_text(encoding="utf-8"))
        assert len(pack["items"]) == len(oracle["items"]) == 100
        assert {item["schema"] for item in pack["items"]} == {"E1", "E2", "H1", "H2", "H3"}
        assert all(item["memory_required"] for item in pack["items"])
        assert all("answer_projection" not in item["current_task"] for item in pack["items"])
        pack_manifest = json.loads((first / "pack-manifest.json").read_text(encoding="utf-8"))
        assert "seed" not in pack
        assert pack_manifest["runtime_files"] == ["task-pack.json"]
        assert pack_manifest["verifier_only_files"] == ["oracle.json", "verifier-provenance.json"]

        manifest = root / "run-manifest.json"
        run(
            "prepare", "--pack", str(first), "--output", str(manifest),
            "--protocol-commit", GIT_A, "--omp-version", "17.3.5", "--runner-sha", SHA_B,
            "--input-tokens", "12000", "--output-tokens", "2000", "--tool-calls", "40", "--wall-seconds", "900",
        )
        prepared = json.loads(manifest.read_text(encoding="utf-8"))
        assert set(prepared["arms"]) == {"S0", "S1", "T0", "T1"}
        assert len(prepared["schedule"]) == 400
        assert prepared["oracle_must_not_mount"] is True
        assert prepared["decoding"] == {"temperature": 0, "thinking": "high"}
        assert prepared["runtime"]["selector"] == "anthropic/claude-opus-4-8"
        assert prepared["runtime"]["omp_version"] == "17.3.5"
        assert prepared["runtime"]["retry"] == {"model_fallback": False, "per_arm": False}
        assert prepared["budget_policy"]["wall_seconds"] == {"limit": 900, "enforcement": "hard", "on_exceed": "incomplete_fail"}
        assert prepared["budget_policy"]["input_tokens"] == {"reference_limit": 12000, "enforcement": "recorded", "on_exceed": "report"}
        assert prepared["protocol_commit"] == GIT_A
        assert prepared["runner_sha256"] == SHA_B

        broken = root / "broken"
        shutil.copytree(first, broken)
        task_path = broken / "task-pack.json"
        task_path.write_text(task_path.read_text(encoding="utf-8").replace("Registry", "Leaked registry", 1), encoding="utf-8")
        run("validate", "--pack", str(broken), ok=False)
        run(
            "prepare", "--pack", str(first), "--output", str(root / "bad.json"),
            "--protocol-commit", GIT_A, "--omp-version", "invalid", "--runner-sha", SHA_B,
            "--input-tokens", "1", "--output-tokens", "1", "--tool-calls", "1", "--wall-seconds", "1", ok=False,
        )
        run(
            "prepare", "--pack", str(first), "--output", str(root / "bad-runner.json"),
            "--protocol-commit", GIT_A, "--omp-version", "17.3.5", "--runner-sha", "invalid",
            "--input-tokens", "1", "--output-tokens", "1", "--tool-calls", "1", "--wall-seconds", "1", ok=False,
        )
    print("AGENT-BENCHMARK-TEST-OK")


if __name__ == "__main__":
    main()
