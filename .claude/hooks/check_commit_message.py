#!/usr/bin/env python3
"""PreToolUse hook (Bash): git commit 메시지 컨벤션을 강제한다.

규칙(→ rules/commit_conventions.md):
  - 형식: `type: subject`  (type ∈ feat|fix|docs|style|refactor|test|chore)
  - 영어로 작성 (제목에 한글 금지)

`git commit -m "..."` 의 메시지만 검사한다. 에디터로 여는 커밋(-m 없음),
merge/revert/fixup 자동 메시지는 통과시킨다. 위반 시 exit 2 로 차단.
"""
import sys
import json
import re
import shlex

ALLOWED = ("feat", "fix", "docs", "style", "refactor", "test", "chore")
SUBJECT_RE = re.compile(r"^(feat|fix|docs|style|refactor|test|chore)(\([^)]+\))?: .+")
HANGUL_RE = re.compile(r"[가-힣]")
AUTO_PREFIX = ("Merge ", "Revert ", "fixup!", "squash!")


def extract_messages(cmd: str):
    try:
        toks = shlex.split(cmd)
    except Exception:
        return None  # 파싱 실패 → 검사 불가
    # git commit 명령인지 확인
    if "git" not in toks or "commit" not in toks:
        return None
    msgs, i = [], 0
    while i < len(toks):
        t = toks[i]
        if t in ("-m", "--message") or re.fullmatch(r"-[A-Za-z]*m", t):
            if i + 1 < len(toks):
                msgs.append(toks[i + 1])
                i += 2
                continue
        i += 1
    return msgs


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    cmd = data.get("tool_input", {}).get("command", "")
    if "commit" not in cmd:
        sys.exit(0)

    msgs = extract_messages(cmd)
    if not msgs:
        sys.exit(0)  # -m 없음(에디터) 또는 파싱 불가 → 통과

    subject = msgs[0].splitlines()[0].strip()
    full = "\n".join(msgs)

    if subject.startswith(AUTO_PREFIX):
        sys.exit(0)

    if HANGUL_RE.search(full):
        sys.stderr.write(
            "BLOCKED: 커밋 메시지는 영어로 작성하세요 (한글 감지).\n"
            f"  메시지: {subject}\n"
            "  예: feat: add login feature\n"
        )
        sys.exit(2)

    if not SUBJECT_RE.match(subject):
        sys.stderr.write(
            "BLOCKED: 커밋 메시지 형식 위반 — 'type: subject' 형식이어야 합니다.\n"
            f"  메시지: {subject}\n"
            f"  허용 타입: {', '.join(ALLOWED)}\n"
            "  예: fix: fix login error\n"
        )
        sys.exit(2)

    sys.exit(0)


if __name__ == "__main__":
    main()
