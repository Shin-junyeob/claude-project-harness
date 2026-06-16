#!/usr/bin/env bash
# PreToolUse hook (Bash): 사용자의 명시적 명령 없이 원격 저장소(repo) 삭제 시도를 차단한다.
# stdin 으로 Claude Code 가 tool 입력 JSON 을 전달한다.
# 차단하려면 exit code 2 와 stderr 메시지를 사용한다.
#
# 차단 대상:
#   - gh repo delete ...
#   - gh api ... -X DELETE ... /repos/...   (또는 --method DELETE)
#   - git push ... --delete ... / git push ... :<branch>   (원격 브랜치 삭제)

input="$(cat)"

# tool_input.command 추출 (jq → python3 → 원문 순)
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
else
  cmd="$input"
fi

shopt -s nocasematch 2>/dev/null

blocked=""
# gh repo delete
if [[ "$cmd" =~ gh(\.exe)?[[:space:]]+repo[[:space:]]+delete ]]; then
  blocked="gh repo delete"
# gh api 로 repo DELETE
elif [[ "$cmd" =~ gh(\.exe)?[[:space:]]+api ]] \
     && [[ "$cmd" =~ (-X|--method)[[:space:]]+DELETE ]] \
     && [[ "$cmd" =~ /repos/ ]]; then
  blocked="gh api DELETE /repos/"
# git push 로 원격 브랜치 삭제
elif [[ "$cmd" =~ git[[:space:]]+push ]] \
     && [[ "$cmd" =~ (--delete|[[:space:]]:[A-Za-z0-9._/-]+) ]]; then
  blocked="git push --delete (원격 브랜치 삭제)"
fi

if [[ -n "$blocked" ]]; then
  echo "BLOCKED: 원격 저장소/브랜치 삭제($blocked)는 사용자의 명시적 명령이 있을 때만 허용됩니다." >&2
  echo "사용자가 명시적으로 'repo 삭제해줘' 라고 지시한 경우에만 이 훅을 우회하세요." >&2
  exit 2
fi

exit 0
