#!/usr/bin/env bash
# PreToolUse hook (Bash): stable 브랜치로의 merge/push 를 CI 통과 시에만 허용한다.
# stdin 으로 tool 입력 JSON 을 받는다. 차단 시 exit 2 + stderr (fallback).
#
# 동작:
#   1) stable 로 merge/push 하려는 명령인지 감지
#   2) 맞다면 main 브랜치의 최신 CI(GitHub Actions) 결과를 gh 로 확인
#      - success  → 허용(exit 0)
#      - 그 외(실패/대기/없음/확인불가) → 차단(exit 2)  ← fallback

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
else
  cmd="$input"
fi

shopt -s nocasematch 2>/dev/null

# ── stable merge/push 패턴 감지 ──────────────────────────────────────
is_stable_merge=false
if [[ "$cmd" =~ git[[:space:]]+merge && "$cmd" =~ stable ]] \
   || [[ "$cmd" =~ checkout[[:space:]]+stable && "$cmd" =~ merge ]] \
   || [[ "$cmd" =~ git[[:space:]]+push.*stable ]]; then
  is_stable_merge=true
fi
# 2단계 절차 보강: 현재 브랜치가 stable 인 상태에서의 `git merge`(브랜치명 미포함)도 감지
if [[ "$is_stable_merge" == false && "$cmd" =~ git[[:space:]]+merge ]]; then
  cur="$(git -C "${CLAUDE_PROJECT_DIR:-.}" branch --show-current 2>/dev/null)"
  [[ "$cur" == "stable" ]] && is_stable_merge=true
fi

[[ "$is_stable_merge" == false ]] && exit 0   # 관련 명령 아님 → 통과

# ── CI 결과 확인 ─────────────────────────────────────────────────────
block() {
  echo "BLOCKED: stable merge 차단(fallback) — $1" >&2
  echo "main 브랜치 CI가 success 여야 stable 로 merge 할 수 있습니다." >&2
  exit 2
}

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || true
command -v gh >/dev/null 2>&1 || block "gh CLI 없음 — CI 확인 불가"

concl="$(gh run list --branch main --limit 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null)"

case "$concl" in
  success)
    echo "✔ main CI success 확인 — stable merge 허용" >&2
    exit 0
    ;;
  "" )
    block "CI 실행 기록 없음(워크플로 미설정/원격 미연결)"
    ;;
  * )
    block "최신 CI 결과='$concl' (success 아님)"
    ;;
esac
