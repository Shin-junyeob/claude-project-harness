#!/usr/bin/env python3
"""PreToolUse hook (Read, Bash): 실제 .env 파일 직접 확인을 차단한다.

.env 의 값은 런타임에 python-dotenv 로만 로드한다. 에이전트/도구가 .env 값을
직접 열람(대화·로그 유출)하지 않도록 Read·cat/grep 류를 막는다.
값 없는 템플릿(.env.example/.sample/.template/.dist)은 허용한다.
(→ rules/env_management.md)
"""
import sys
import json
import re

# .env 를 읽어 출력하는 명령들
READERS = re.compile(
    r"(?<![\w./-])(cat|less|more|head|tail|nl|tac|strings|xxd|hexdump|od|bat|batcat|grep|egrep|rg)\b"
)
# .env 파일 참조(단, .env.example/.sample/.template/.dist 는 제외)
ENV_REF = re.compile(
    r"""(?:^|[\s/'"=(:])\.env(?![\w])(?!\.(?:example|sample|template|dist))"""
)


def is_real_env_path(p: str) -> bool:
    base = p.replace("\\", "/").rsplit("/", 1)[-1]
    if base == ".env":
        return True
    if base.startswith(".env.") and not base.endswith(
        (".example", ".sample", ".template", ".dist")
    ):
        return True
    return False


def block(what: str) -> None:
    sys.stderr.write(
        f"BLOCKED: .env 직접 확인 금지({what}). 값은 런타임에 python-dotenv 로 로드하세요.\n"
        ".env.example 로 필요한 키 목록을 확인하고, 값이 채워져 있다고 가정해 실행하세요.\n"
        "(→ rules/env_management.md)\n"
    )
    sys.exit(2)


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    tool = data.get("tool_name", "")
    ti = data.get("tool_input", {}) or {}

    if tool == "Read":
        target = ti.get("file_path") or ti.get("path") or ""
        if is_real_env_path(target):
            block(f".env 읽기: {target}")
    elif tool == "Bash":
        cmd = ti.get("command", "")
        if READERS.search(cmd) and ENV_REF.search(cmd):
            block("cat/grep 등으로 .env 출력")

    sys.exit(0)


if __name__ == "__main__":
    main()
