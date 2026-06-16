#!/usr/bin/env python3
"""PostToolUse hook: 도구 실행이 에러로 끝나면 logs/ 에 자동 기록한다.

Bash 등의 도구 결과에서 에러 신호를 감지하면 프로젝트 logs/error_log.md 에
타임스탬프와 함께 append 한다. 항상 exit 0 (비차단).
"""
import sys
import json
import os
from datetime import datetime
from pathlib import Path


def find_project_root(start: Path) -> Path:
    """가장 가까운 .claude 폴더를 가진 디렉토리를 프로젝트 루트로 본다."""
    cur = start.resolve()
    for parent in [cur, *cur.parents]:
        if (parent / ".claude").is_dir():
            return parent
    return cur


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool_response = data.get("tool_response", {})
    # 에러 신호 감지
    is_error = False
    if isinstance(tool_response, dict):
        if tool_response.get("is_error") or tool_response.get("error"):
            is_error = True
        stderr = str(tool_response.get("stderr", ""))
        if stderr and ("error" in stderr.lower() or "traceback" in stderr.lower()):
            is_error = True

    if not is_error:
        sys.exit(0)

    cwd = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd()))
    root = find_project_root(cwd)
    logs_dir = root / "logs"
    logs_dir.mkdir(exist_ok=True)

    tool_name = data.get("tool_name", "unknown")
    entry = (
        f"\n## {datetime.now().isoformat(timespec='seconds')} — {tool_name}\n"
        f"```\n{json.dumps(tool_response, ensure_ascii=False)[:1000]}\n```\n"
    )
    with open(logs_dir / "error_log.md", "a", encoding="utf-8") as f:
        f.write(entry)

    sys.exit(0)


if __name__ == "__main__":
    main()
