#!/usr/bin/env python3
"""PreToolUse hook (Write|Edit): 구현 코드는 src/ 안에만 작성하도록 강제한다.

코드 파일을 src/ 밖에 쓰려고 하면 차단(exit 2)한다.
설정/문서/스크립트/훅 등은 예외로 허용한다.
"""
import sys
import json
from pathlib import PurePosixPath

# 구현 코드로 간주하는 확장자
CODE_EXTS = {
    ".py", ".js", ".ts", ".jsx", ".tsx", ".cs", ".java", ".go",
    ".rb", ".rs", ".cpp", ".cc", ".cxx", ".c", ".h", ".hpp",
    ".php", ".kt", ".swift", ".scala", ".m",
}

# 이 경로 요소가 들어있으면 예외(허용)
EXEMPT_DIRS = {"src", ".claude", "tests", "test", "tools", "scripts", "node_modules", "venv", ".venv"}


def is_exempt(path: str) -> bool:
    parts = [p for p in PurePosixPath(path.replace("\\", "/")).parts]
    # 경로에 예외 디렉토리가 포함되면 허용
    if any(part in EXEMPT_DIRS for part in parts):
        return True
    name = parts[-1] if parts else ""
    # 테스트 파일 관례 허용
    if name.startswith("test_") or name.rsplit(".", 1)[0].endswith("_test"):
        return True
    # 셸 스크립트는 도구/세팅 용도가 많아 허용(new-project.sh 등)
    if name.endswith(".sh"):
        return True
    return False


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    target = data.get("tool_input", {}).get("file_path") \
        or data.get("tool_input", {}).get("path") or ""
    if not target:
        sys.exit(0)

    ext = PurePosixPath(target.replace("\\", "/")).suffix.lower()
    if ext not in CODE_EXTS:
        sys.exit(0)  # 코드 파일 아님 → 통과
    if is_exempt(target):
        sys.exit(0)

    sys.stderr.write(
        f"BLOCKED: 구현 코드는 src/ 안에 작성하세요 — '{target}' 는 src/ 밖입니다.\n"
        "(규칙: rules/project_structure.md — 구현 코드는 src/ 에만)\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
