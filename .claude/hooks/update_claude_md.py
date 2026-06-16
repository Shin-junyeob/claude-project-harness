#!/usr/bin/env python3
"""PostToolUse hook: CLAUDE.md 가 저장되면 이정표 형식을 검증한다.

CLAUDE.md 는 이정표(경로 지도) 역할만 해야 한다. 필수 섹션이 빠졌으면
stderr 로 경고만 출력한다(차단하지 않음, exit 0).
"""
import sys
import json
from pathlib import Path

REQUIRED_SECTIONS = ["## 이 파일의 역할", "## 경로 참조표", "## 구조 계약"]


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    target = tool_input.get("file_path") or tool_input.get("path") or ""
    if not target.endswith("CLAUDE.md"):
        sys.exit(0)

    path = Path(target)
    if not path.exists():
        sys.exit(0)

    content = path.read_text(encoding="utf-8")
    missing = [s for s in REQUIRED_SECTIONS if s not in content]
    if missing:
        sys.stderr.write(
            "WARNING: CLAUDE.md 에 권장 섹션이 누락되었습니다: "
            + ", ".join(missing)
            + "\nCLAUDE.md 는 이정표(경로 지도) 형식을 유지하세요.\n"
        )
    sys.exit(0)


if __name__ == "__main__":
    main()
