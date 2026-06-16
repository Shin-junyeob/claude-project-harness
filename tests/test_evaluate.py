"""tools/evaluate.py 평가기 검증 — reproduce/generalize/threshold/오류 케이스.

evaluate.py 를 서브프로세스로 실행해 종료코드(0=PASS,1=FAIL,2=오류)를 검증한다.
spec 은 JSON 으로 작성한다(PyYAML 유무와 무관하게 파싱되도록).
"""
import json
import subprocess
import sys
from pathlib import Path

EVAL = Path(__file__).resolve().parent.parent / "tools" / "evaluate.py"


def _run(tmp_path, spec, files):
    (tmp_path / "spec.json").write_text(json.dumps(spec), encoding="utf-8")
    for rel, content in files.items():
        p = tmp_path / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
    r = subprocess.run([sys.executable, str(EVAL), "spec.json"],
                       cwd=tmp_path, capture_output=True, text=True)
    return r.returncode


def test_text_match(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "o.txt"}, "golden": {"path": "g.txt", "compare": "auto"}},
                {"o.txt": "hi\n", "g.txt": "hi\n"}) == 0


def test_text_mismatch(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "o.txt"}, "golden": {"path": "g.txt", "compare": "auto"}},
                {"o.txt": "HI\n", "g.txt": "hi\n"}) == 1


def test_json_equal_unordered(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "o.json"}, "golden": {"path": "g.json", "compare": "json"}},
                {"o.json": '{"b":2,"a":1}', "g.json": '{"a":1,"b":2}'}) == 0


def test_threshold_any_mode(tmp_path):
    # auto(text) 모드라도 threshold<1.0 이면 유사도로 통과
    assert _run(tmp_path,
                {"produce": {"output_path": "o.txt"},
                 "golden": {"path": "g.txt", "compare": "auto", "threshold": 0.8}},
                {"o.txt": "abcdefghiX", "g.txt": "abcdefghij"}) == 0


def test_golden_unset_pass(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "o.txt"}, "golden": {"path": ""}},
                {"o.txt": "x"}) == 0


def test_output_missing_fail(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "nope.txt"}, "golden": {"path": ""}}, {}) == 1


def test_dir_match(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "od"}, "golden": {"path": "gd", "compare": "auto"}},
                {"od/a.txt": "x", "od/b.txt": "y", "gd/a.txt": "x", "gd/b.txt": "y"}) == 0


def test_dir_missing_file_fail(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "od"}, "golden": {"path": "gd", "compare": "auto"}},
                {"od/a.txt": "x", "gd/a.txt": "x", "gd/b.txt": "y"}) == 1


def test_generalize_uses_holdout(tmp_path):
    assert _run(tmp_path,
                {"produce": {"output_path": "train.txt", "holdout_output_path": "ho.txt"},
                 "golden": {"mode": "generalize", "path": "gtrain.txt",
                            "holdout_path": "ghold.txt", "compare": "auto"}},
                {"train.txt": "ANY", "gtrain.txt": "DIFFERENT",
                 "ho.txt": "match\n", "ghold.txt": "match\n"}) == 0


def test_generalize_requires_holdout_config(tmp_path):
    # generalize 인데 holdout 경로 미지정 → 설정 오류(2)
    assert _run(tmp_path,
                {"produce": {"output_path": "o.txt"},
                 "golden": {"mode": "generalize", "path": "g.txt"}},
                {"o.txt": "x", "g.txt": "x"}) == 2


def test_generalize_does_not_leak_holdout(tmp_path):
    # generalize FAIL 시 holdout golden 의 고유 문자열이 로그로 새면 안 된다(게이밍 방지).
    sentinel = "GOLDEN_SECRET_42"
    rc = _run(tmp_path,
              {"produce": {"output_path": "t.txt", "holdout_output_path": "ho.txt"},
               "golden": {"mode": "generalize", "path": "gt.txt",
                          "holdout_path": "gh.txt", "compare": "auto"}},
              {"t.txt": "x", "gt.txt": "x",
               "ho.txt": "wrong\n", "gh.txt": sentinel + "\n"})
    assert rc == 1  # 불일치
    latest = (tmp_path / "logs/eval/latest.json").read_text(encoding="utf-8")
    iters = (tmp_path / "logs/iterations.md").read_text(encoding="utf-8")
    assert sentinel not in latest, "holdout golden 이 latest.json 으로 누출됨"
    assert sentinel not in iters, "holdout golden 이 iterations.md 로 누출됨"
