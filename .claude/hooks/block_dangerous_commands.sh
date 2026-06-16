#!/usr/bin/env bash
# PreToolUse hook (Bash): 되돌리기 어려운 위험 명령을 차단한다.
# stdin 으로 tool 입력 JSON 을 받는다. 차단 시 exit 2 + stderr.
#
# 차단 대상:
#   - rm -rf 로 루트(/) · 홈(~,$HOME) · 와일드카드(*) · 상위경로(..) · 시스템 디렉토리 삭제
#   - git push --force / -f (강제 푸시)
#   - git reset --hard (커밋·작업 손실)
#   - git clean -f (추적 안 된 파일 강제 삭제)
#   - dd / mkfs / 블록디바이스 덮어쓰기 등 디스크 파괴

input="$(cat)"
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
elif command -v python3 >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)"
else
  cmd="$input"
fi

reason=""

# ── rm 위험 타깃 감지 ────────────────────────────────────────────────
# 위험 경로가 'rm 의 실제 인자'일 때만 차단한다(앞에 다른 명령의 경로가 있어도 오탐 방지).
# 패턴: rm  [플래그...]  <위험경로>
dt='(/|/\*|\*|~|~/|\$HOME|\$\{HOME\}|\.\.|\.\./|/etc|/usr|/bin|/sbin|/lib|/var|/boot|/dev|/sys|/proc|/root|/home|/mnt/c|/mnt/c/Users)'
if [[ "$cmd" =~ (^|[^[:alnum:]])rm[[:space:]]+(-[A-Za-z]+[[:space:]]+)*\"?\'?${dt}([[:space:]/\"\']|$) ]]; then
  reason="rm 위험 경로(루트/홈/와일드카드/상위경로/시스템 디렉토리)"
fi

# ── git 강제/파괴 ────────────────────────────────────────────────────
if [[ -z "$reason" ]] && [[ "$cmd" =~ git[[:space:]]+push ]] \
   && [[ "$cmd" =~ (--force([[:space:]]|$)|--force[^-]|[[:space:]]-f([[:space:]]|$)) ]]; then
  reason="git push --force (강제 푸시 — 원격 히스토리 손상 위험)"
fi
if [[ -z "$reason" ]] && [[ "$cmd" =~ git[[:space:]]+reset[[:space:]]+.*--hard ]]; then
  reason="git reset --hard (커밋·작업 손실)"
fi
if [[ -z "$reason" ]] && [[ "$cmd" =~ git[[:space:]]+clean[[:space:]]+-[[:alnum:]]*f ]]; then
  reason="git clean -f (추적 안 된 파일 강제 삭제)"
fi

# ── 디스크 파괴 ──────────────────────────────────────────────────────
if [[ -z "$reason" ]] && [[ "$cmd" =~ (^|[^[:alnum:]])(dd|mkfs([.][[:alnum:]]+)?)[[:space:]] ]]; then
  reason="dd/mkfs (디스크 직접 쓰기)"
fi
if [[ -z "$reason" ]] && [[ "$cmd" =~ \>[[:space:]]*/dev/(sd|nvme|hd|disk) ]]; then
  reason="블록 디바이스 덮어쓰기"
fi

if [[ -n "$reason" ]]; then
  echo "BLOCKED: 위험 명령 차단 — $reason" >&2
  echo "정말 필요하면 사용자가 직접(이 세션 밖에서) 실행하거나, 명시적으로 우회를 지시하세요." >&2
  exit 2
fi

exit 0
