#!/usr/bin/env python3
"""PreToolUse hook: 지정된 민감 경로에 대한 수정(Write/Edit) 시도를 차단한다.

차단 대상 경로는 같은 폴더의 sensitive_paths.txt 에 줄 단위로 적는다.
(glob 패턴 지원, '#' 으로 시작하는 줄은 주석)

차단하려면 exit code 2 와 stderr 메시지를 쓴다.
"""
import sys
import json
import fnmatch
from pathlib import Path

HOOK_DIR = Path(__file__).resolve().parent
LIST_FILE = HOOK_DIR / "sensitive_paths.txt"


def load_patterns():
    if not LIST_FILE.exists():
        return []
    patterns = []
    for line in LIST_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            patterns.append(line)
    return patterns


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)  # 입력 파싱 실패 시 통과

    tool_input = data.get("tool_input", {})
    target = tool_input.get("file_path") or tool_input.get("path") or ""
    if not target:
        sys.exit(0)

    patterns = load_patterns()
    for pat in patterns:
        if fnmatch.fnmatch(target, pat) or pat in target:
            sys.stderr.write(f"BLOCKED: '{target}' 는 보호된 민감 경로입니다 (패턴: {pat}).\n")
            sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
