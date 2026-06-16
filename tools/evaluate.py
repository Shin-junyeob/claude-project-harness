#!/usr/bin/env python3
"""평가기 — produce 결과물을 golden data 와 비교해 통과 여부를 판정한다.

사용:  python tools/evaluate.py [spec.yaml]
종료코드:  0 = 통과(PASS), 1 = 실패(FAIL), 2 = 설정/입력 오류

판정은 logs/eval/latest.json 에 저장하고 logs/iterations.md 에 한 줄 요약을 append 한다.
자율 루프(/autoloop, ralph 등)는 이 종료코드를 'golden 도달' 오라클로 사용한다.

## golden.mode
- reproduce (기본): 고정 1회성 산출물 재현. output_path 를 golden.path 와 비교.
- generalize: 변하는 입력을 처리하는 생성기. **holdout** 으로만 최종 판정한다
  (produce.holdout_output_path 를 golden.holdout_path 와 비교). 루프/fix 단계는 holdout golden 을
  보면 안 된다(오라클 게이밍 방지). train golden 은 개발용일 뿐 최종 게이트가 아니다.

## threshold
golden.threshold < 1.0 이면 모든 비교 모드에서 유사도(0~1)가 threshold 이상이면 PASS 로 본다.
"""
from __future__ import annotations

import json
import sys
import hashlib
import difflib
from datetime import datetime
from pathlib import Path


class SpecError(Exception):
    pass


def load_spec(spec_path: Path) -> dict:
    text = spec_path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text) or {}
    except ImportError:
        try:
            return json.loads(text)  # PyYAML 없으면 JSON spec 만 허용
        except json.JSONDecodeError as e:
            raise SpecError(
                "PyYAML 미설치 + spec 이 JSON 형식도 아닙니다. 'pip install pyyaml' (또는 make setup) 후 재시도."
            ) from e


def _read_text(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")


def _ratio_and_diff(a: str, b: str) -> tuple[float, str]:
    """두 텍스트의 유사도(0~1)와 unified diff(최대 4000자)를 반환."""
    ratio = difflib.SequenceMatcher(None, a, b).ratio()
    diff = "".join(difflib.unified_diff(
        a.splitlines(keepends=True), b.splitlines(keepends=True),
        fromfile="golden", tofile="output", n=2))
    return ratio, diff[:4000]


def compare_text(out: Path, gold: Path) -> tuple[bool, float, str]:
    a, b = _read_text(gold), _read_text(out)
    if a == b:
        return True, 1.0, "텍스트 일치"
    return (False, *_ratio_and_diff(a, b))


def compare_json(out: Path, gold: Path) -> tuple[bool, float, str]:
    a, b = json.loads(_read_text(gold)), json.loads(_read_text(out))
    if a == b:
        return True, 1.0, "JSON 일치"
    sa = json.dumps(a, ensure_ascii=False, sort_keys=True, indent=2)
    sb = json.dumps(b, ensure_ascii=False, sort_keys=True, indent=2)
    return (False, *_ratio_and_diff(sa, sb))


def compare_bytes(out: Path, gold: Path) -> tuple[bool, float, str]:
    ha = hashlib.sha256(gold.read_bytes()).hexdigest()
    hb = hashlib.sha256(out.read_bytes()).hexdigest()
    ok = ha == hb
    return ok, (1.0 if ok else 0.0), ("바이트 일치" if ok else f"해시 불일치 g={ha[:12]} o={hb[:12]}")


def compare_dir(out: Path, gold: Path, mode: str, threshold: float) -> tuple[bool, float, str]:
    gfiles = {p.relative_to(gold): p for p in gold.rglob("*") if p.is_file()}
    ofiles = {p.relative_to(out): p for p in out.rglob("*") if p.is_file()}
    missing = sorted(set(gfiles) - set(ofiles))
    extra = sorted(set(ofiles) - set(gfiles))
    notes, ratios = [], []
    ok = not missing
    for rel in sorted(set(gfiles) & set(ofiles)):
        sub_ok, ratio, _ = compare_one(ofiles[rel], gfiles[rel], mode, threshold)
        ratios.append(ratio)
        if not sub_ok:
            ok = False
            notes.append(f"불일치: {rel}")
    if missing:
        notes.append("누락: " + ", ".join(str(m) for m in missing[:10]))
    if extra:
        notes.append("초과: " + ", ".join(str(e) for e in extra[:10]))
    avg = sum(ratios) / len(ratios) if ratios else (1.0 if ok else 0.0)
    return ok, avg, "\n".join(notes) or "디렉토리 일치"


def _infer_mode(path: Path) -> str:
    ext = path.suffix.lower()
    if ext == ".json":
        return "json"
    if ext in {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".xlsx", ".xlsm", ".zip", ".bin"}:
        return "bytes"
    return "text"


def compare_one(out: Path, gold: Path, mode: str, threshold: float) -> tuple[bool, float, str]:
    m = _infer_mode(gold) if mode in ("auto", "similarity") else mode
    if m == "json":
        ok, ratio, detail = compare_json(out, gold)
    elif m == "bytes":
        ok, ratio, detail = compare_bytes(out, gold)
    else:  # text / csv
        ok, ratio, detail = compare_text(out, gold)
    # 전 모드 공통: threshold < 1.0 이면 유사도 기준으로 통과 허용
    if not ok and threshold < 1.0 and ratio >= threshold:
        return True, ratio, f"유사 통과 score={ratio:.4f} >= {threshold}"
    return ok, ratio, detail


def _resolve_targets(spec: dict) -> tuple[str, str, str, float, str]:
    """golden.mode 에 따라 (output, golden, compare, threshold, mode) 를 결정."""
    produce = spec.get("produce", {}) or {}
    golden = spec.get("golden", {}) or {}
    mode = golden.get("mode", "reproduce")
    compare = golden.get("compare", "auto")
    threshold = float(golden.get("threshold", 1.0))
    if mode == "generalize":
        out = produce.get("holdout_output_path", "")
        gold = golden.get("holdout_path", "")
        if not out or not gold:
            raise SpecError(
                "generalize 모드는 produce.holdout_output_path 와 golden.holdout_path 가 필요합니다 "
                "(오라클 게이밍 방지를 위해 최종 판정은 holdout 으로만 합니다)."
            )
    else:
        out = produce.get("output_path", "")
        gold = golden.get("path", "")
    return out, gold, compare, threshold, mode


def main() -> int:
    spec_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("spec.yaml")
    if not spec_path.exists():
        print(f"[evaluate] spec 없음: {spec_path}", file=sys.stderr)
        return 2
    try:
        spec = load_spec(spec_path)
        out_s, gold_s, compare, threshold, mode = _resolve_targets(spec)
    except SpecError as e:
        print(f"[evaluate] 설정 오류: {e}", file=sys.stderr)
        return 2

    ts = datetime.now().isoformat(timespec="seconds")
    Path("logs/eval").mkdir(parents=True, exist_ok=True)

    if not out_s or not Path(out_s).exists():
        return _finish({"ts": ts, "mode": mode, "result": "FAIL",
                        "reason": f"결과물 없음: {out_s}", "score": 0.0}, 1)

    if not gold_s:  # golden 미지정(reproduce 한정) → 생성 여부만 확인
        return _finish({"ts": ts, "mode": mode, "result": "PASS",
                        "reason": "결과물 생성됨(golden 미지정)", "score": None}, 0)

    gp, op = Path(gold_s), Path(out_s)
    if not gp.exists():
        return _finish({"ts": ts, "mode": mode, "result": "FAIL",
                        "reason": f"golden 없음: {gp}", "score": 0.0}, 1)

    if gp.is_dir():
        ok, score, detail = compare_dir(op, gp, compare, threshold)
    else:
        ok, score, detail = compare_one(op, gp, compare, threshold)

    return _finish({"ts": ts, "mode": mode, "result": "PASS" if ok else "FAIL",
                    "score": round(score, 4), "compare": compare, "threshold": threshold,
                    "output": str(op), "golden": str(gp), "detail": detail}, 0 if ok else 1)


def _finish(verdict: dict, code: int) -> int:
    # generalize 모드: holdout golden 내용(diff)이 로그를 통해 fix 단계로 새지 않도록
    # detail(diff)을 비공개 처리한다. score/result 만 적합도 신호로 남긴다.
    if verdict.get("mode") == "generalize" and "detail" in verdict:
        verdict["detail"] = "(generalize: holdout 상세 비공개 — 게이밍 방지, score 만 제공)"
    Path("logs/eval/latest.json").write_text(
        json.dumps(verdict, ensure_ascii=False, indent=2), encoding="utf-8")
    summary = verdict.get("reason") or verdict.get("detail", "")
    line = f"- {verdict['ts']} [{verdict['result']}] mode={verdict.get('mode')} score={verdict.get('score')} {summary[:100]}\n"
    with open("logs/iterations.md", "a", encoding="utf-8") as f:
        f.write(line)
    stream = sys.stdout if code == 0 else sys.stderr
    print(f"[evaluate] {verdict['result']} — score={verdict.get('score')} mode={verdict.get('mode')}", file=stream)
    return code


if __name__ == "__main__":
    sys.exit(main())
