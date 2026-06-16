#!/usr/bin/env bash
#
# publish.sh — 하네스만 안전하게 추출해 public 저장소로 동기화한다.
#
# 사용법:  ./publish.sh ["커밋 메시지"]
#
# 안전 설계:
#   - 발행 화이트리스트(아래 DIRS/FILES)만 복사 → 회사 프로젝트·개인파일은 구조적으로 제외
#   - 런타임/개인 잔재(.omc, settings.local.json, worktrees, __pycache__) 제거
#   - 비밀/머신종속경로 스캔 게이트 — 발견 시 푸시하지 않고 중단
#   - 원격 클론에 덮어써 commit/push (히스토리 보존, 변경 있을 때만)
#
# 원격 변경:  HARNESS_REMOTE=git@github.com:<you>/<repo>.git ./publish.sh
#
set -euo pipefail

GLOBAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE="${HARNESS_REMOTE:-git@github.com:Shin-junyeob/claude-project-harness.git}"
WORK="$GLOBAL_DIR/.publish-workdir"

# ── 발행 화이트리스트 ────────────────────────────────────────────────
DIRS=(rules .claude/hooks .claude/agents .claude/commands .github .githooks mcp tools tests docs)
FILES=(.claude/settings.json spec.template.yaml pyproject.toml Makefile .env.example
       .pre-commit-config.yaml .gitignore .gitattributes .editorconfig
       new-project.sh new-project-guide.html publish.sh CLAUDE.md README.md)

echo "▶ 하네스 발행 동기화 → $REMOTE"

# ── 1) 원격 작업본 준비(클론 또는 최신화) ───────────────────────────
if [[ -d "$WORK/.git" ]]; then
  git -C "$WORK" fetch -q origin && git -C "$WORK" reset -q --hard origin/main
else
  rm -rf "$WORK"
  git clone -q "$REMOTE" "$WORK"
fi

# ── 2) 작업본 내용 비우기(.git 보존) — 소스 삭제가 원격에도 전파되도록 ─
find "$WORK" -mindepth 1 -maxdepth 1 ! -name '.git' -exec rm -rf {} +

# ── 3) 화이트리스트만 복사 ───────────────────────────────────────────
for d in "${DIRS[@]}"; do
  [[ -e "$GLOBAL_DIR/$d" ]] && { mkdir -p "$WORK/$(dirname "$d")"; cp -r "$GLOBAL_DIR/$d" "$WORK/$d"; }
done
for f in "${FILES[@]}"; do
  [[ -e "$GLOBAL_DIR/$f" ]] && { mkdir -p "$WORK/$(dirname "$f")"; cp "$GLOBAL_DIR/$f" "$WORK/$f"; }
done

# ── 4) 런타임/개인 잔재 제거(이중 안전) ──────────────────────────────
find "$WORK" -name '.omc' -type d -prune -exec rm -rf {} + 2>/dev/null || true
find "$WORK" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
rm -f "$WORK/.claude/settings.local.json" "$WORK/.claude/scheduled_tasks.lock" 2>/dev/null || true
rm -rf "$WORK/.claude/worktrees" 2>/dev/null || true

# ── 5) 비밀/사설 스캔 게이트 (발견 시 중단) ──────────────────────────
echo "  · 비밀/사설 경로 스캔..."
leak=0
# 스캐너 자신(publish.sh)은 탐지 패턴 문자열을 포함하므로 제외(자기참조 오탐 방지)
SCAN_EXCL=(--exclude-dir=.git --exclude=publish.sh)
if grep -rEn 'gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[baprs]-|Bearer [A-Za-z0-9._-]{20,}' "$WORK" "${SCAN_EXCL[@]}" 2>/dev/null; then
  echo "❌ 토큰형 시크릿 발견 — 발행 중단" >&2; leak=1
fi
if grep -rIn '/mnt/c/Users/user\|/home/junyub\|제조2팀\|제조기술\|관리팀\|knkcl@' "$WORK" "${SCAN_EXCL[@]}" 2>/dev/null; then
  echo "❌ 머신 종속 경로/사설명 발견 — 발행 중단(플레이스홀더로 바꾼 뒤 재시도)" >&2; leak=1
fi
[[ "$leak" -ne 0 ]] && exit 1
echo "  · 스캔 통과(누출 0)"

# ── 6) 커밋 & 푸시 (변경 있을 때만) ──────────────────────────────────
cd "$WORK"
git add -A
if git diff --cached --quiet; then
  echo "✅ 변경 없음 — 원격이 이미 최신입니다."
  exit 0
fi
echo "  · 변경 파일:"; git diff --cached --name-status | sed 's/^/      /'
MSG="${1:-chore: sync harness}"
git -c user.name="${GIT_AUTHOR_NAME:-harness}" -c user.email="${GIT_AUTHOR_EMAIL:-harness@local}" commit -q -m "$MSG"
git push -q origin main
echo "✅ 발행 완료: $MSG"
git log --oneline -1
