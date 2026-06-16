#!/usr/bin/env bash
#
# new-project.sh — 전역 디렉토리의 공통 세팅을 새 프로젝트 폴더로 복사한다.
#
# 사용법:  ./new-project.sh <프로젝트명>
#
# 동작:
#   - 공통 항목 복사: rules/, .claude/(hooks·agents·commands·settings.json), tools/, tests/,
#       .github/(CI), .githooks/(pre-commit), spec.template.yaml, pyproject.toml, Makefile,
#       .env.example, .pre-commit-config.yaml, .gitignore, .gitattributes, .editorconfig
#   - 생성: CLAUDE.md / README.md (프로젝트명), docs/ logs/ src/ 빈 폴더(.gitkeep), logs/CHECKPOINT.md
#   - git init 후 main / stable 브랜치 구성 + pre-commit 활성화 + (gh 있으면) GitHub private 연동
#   - 복사 안 함: mcp/(전역 참조), .claude/settings.local.json(프로젝트별 권한 자동관리)
#
set -euo pipefail

# ── 전역 디렉토리 = 이 스크립트가 있는 위치 ──────────────────────────
GLOBAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 인자 검증 ────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "사용법: $0 <프로젝트명>" >&2
  exit 1
fi
NAME="$1"
# 경로 구분자·공백·앞쪽 하이픈 등 위험한 이름만 거부 (한글 등 일반 문자는 허용)
if [[ "$NAME" == */* || "$NAME" == *" "* || "$NAME" == .* || "$NAME" == -* || -z "$NAME" ]]; then
  echo "오류: 프로젝트명에 경로 구분자/공백이 있거나 '.' '-' 로 시작합니다: $NAME" >&2
  exit 1
fi

DEST="$GLOBAL_DIR/$NAME"
if [[ -e "$DEST" ]]; then
  echo "오류: '$DEST' 가 이미 존재합니다. 덮어쓰지 않습니다." >&2
  exit 1
fi

echo "▶ 새 프로젝트 생성: $DEST"
mkdir -p "$DEST"

# ── 복사 화이트리스트 (공통 항목만) ──────────────────────────────────
#   mcp/ 와 기존 프로젝트 폴더, 메모리, 엑셀 등은 복사하지 않는다.
mkdir -p "$DEST/.claude"
cp -r "$GLOBAL_DIR/rules"            "$DEST/rules"
cp -r "$GLOBAL_DIR/.claude/hooks"    "$DEST/.claude/hooks"
cp -r "$GLOBAL_DIR/.claude/agents"   "$DEST/.claude/agents"
cp -r "$GLOBAL_DIR/.claude/commands" "$DEST/.claude/commands"
cp -r "$GLOBAL_DIR/tools"            "$DEST/tools"
cp     "$GLOBAL_DIR/spec.template.yaml" "$DEST/spec.template.yaml"
cp -r "$GLOBAL_DIR/.github"          "$DEST/.github"
cp -r "$GLOBAL_DIR/.githooks"        "$DEST/.githooks"
cp     "$GLOBAL_DIR/.claude/settings.json" "$DEST/.claude/settings.json"
cp -r "$GLOBAL_DIR/tests"            "$DEST/tests"
cp     "$GLOBAL_DIR/.gitignore"      "$DEST/.gitignore"
cp     "$GLOBAL_DIR/.gitattributes"  "$DEST/.gitattributes"
cp     "$GLOBAL_DIR/.editorconfig"   "$DEST/.editorconfig"
cp     "$GLOBAL_DIR/pyproject.toml"  "$DEST/pyproject.toml"
cp     "$GLOBAL_DIR/Makefile"        "$DEST/Makefile"
cp     "$GLOBAL_DIR/.env.example"    "$DEST/.env.example"
cp     "$GLOBAL_DIR/.pre-commit-config.yaml" "$DEST/.pre-commit-config.yaml"

# 복제 시 따라온 런타임 상태(.omc 등) 제거 — 새 프로젝트에 세션 상태가 섞이지 않게 한다.
find "$DEST" -name '.omc' -type d -prune -exec rm -rf {} + 2>/dev/null || true

# ── 표준 빈 폴더 ─────────────────────────────────────────────────────
for d in docs logs src; do
  mkdir -p "$DEST/$d"
  touch "$DEST/$d/.gitkeep"
done

# ── 컨텍스트 체크포인트 시드 (→ rules/context_management.md) ──────────
cat > "$DEST/logs/CHECKPOINT.md" <<'MD'
# CHECKPOINT — 작업 진행 상태 (compact/재시작 시 가장 먼저 재읽기)

> 마일스톤마다 갱신한다. 대화가 아니라 이 파일이 진실의 출처다.

## <시각/마일스톤>
- 한 일:
- 다음 할 일:
- 핵심 결정·제약:
- 관련 파일:
- (실패 시) 가설:
MD

# ── 설정 파일 정책 ───────────────────────────────────────────────────
#   - .claude/settings.json     : 공통 훅. 위 복사 단계에서 전역 원본을 그대로 복제.
#   - .claude/settings.local.json: 권한. 프로젝트마다 경로·목록이 다르므로 복제하지 않고,
#                                  각 프로젝트에서 Claude Code 가 필요에 따라 자동 생성·관리.

# ── CLAUDE.md (이정표 형식) ──────────────────────────────────────────
cat > "$DEST/CLAUDE.md" <<MD
# $NAME
> 한 줄 프로젝트 설명을 여기에 작성하세요.

---

## 이 파일의 역할
이 파일은 **이정표(경로 지도)** 역할만 한다. 규칙·절차·에이전트 정의를 직접 쓰지 않는다.
세부 규칙은 \`rules/\`, 에이전트는 \`.claude/agents/\`, 훅은 \`.claude/hooks/\` 에 둔다.

---

## 경로 참조표
| 관심사 | 경로 | 설명 |
|--------|------|------|
| 코딩 컨벤션 | rules/coding_conventions.md | 공통 코딩 규칙 |
| 프로젝트 구조 | rules/project_structure.md | 표준 폴더 구조 |
| 워크플로 | rules/workflow.md | main/stable 브랜치 전략(stable은 CI 통과 시 merge) |
| 커밋 메시지 | rules/commit_conventions.md | type: subject 영어 커밋 규칙 |
| 자율 실행 | rules/autonomous_workflow.md | spec+golden 기반 produce→evaluate→fix 루프 |
| 컨텍스트 관리 | rules/context_management.md | 외부 체크포인트+재읽기로 긴 루프 유지 |
| 문서 갱신 | rules/doc_update_rules.md | 문서 갱신 정책 |
| 자율 명세 | spec.template.yaml | spec.yaml 로 복사해 작성하는 입력 계약 |
| 평가기 | tools/evaluate.py | 결과물 vs golden 비교 오라클 |
| 자율 진입점 | .claude/commands/autoloop.md | /autoloop 슬래시 커맨드 |
| 작업 명령 | Makefile | make setup/test/lint/run/eval |
| 에이전트 | .claude/agents/ | planner, implementer, validator, doc-updater |
| 훅 | .claude/hooks/ | 접근/위험명령/repo삭제/커밋메시지 차단, src강제, stable CI게이트, 로그 |
| CI | .github/workflows/ci.yml | ruff 린트 + pytest |
| MCP | $GLOBAL_DIR/mcp/ | 전역 MCP 설정 참조(복사 안 함) |

---

## 구조 계약
- 구현 코드는 \`src/\` 에만 둔다(\`tools/\`·\`tests/\` 는 예외).
- 규칙은 \`rules/\`, 에이전트는 \`.claude/agents/\`, 훅은 \`.claude/hooks/\`.
- 에러·이력은 \`logs/\` 에, 컨텍스트 체크포인트는 \`logs/CHECKPOINT.md\` 에 기록한다.
- 수정은 main 브랜치에서, 안정 버전만 stable 로 merge(사용자 명시 명령 + CI 통과 시).
- 자율 실행: \`make setup\` → \`spec.template.yaml\` 을 \`spec.yaml\` 로 작성 → \`/autoloop\`.
MD

# ── README.md ────────────────────────────────────────────────────────
cat > "$DEST/README.md" <<MD
# $NAME

## 개요
(프로젝트 개요를 작성하세요.)

## 폴더 구조
- \`src/\` 구현 코드
- \`rules/\` 코딩·도메인 규칙
- \`docs/\` 설계·명세
- \`logs/\` 에러·이력
- \`.claude/\` 에이전트·훅·설정

## 실행 방법
\`\`\`bash
make setup     # venv + 의존성 설치
make test      # 테스트
make run       # 결과물 생성
\`\`\`

## 자율 실행 (golden data 기반 반복)
\`\`\`bash
cp spec.template.yaml spec.yaml   # 프로젝트 설명·결과물·golden 경로 작성
# Claude Code 에서:  /autoloop
\`\`\`
결과물이 golden 에 도달할 때까지 produce→evaluate→fix 를 자동 반복한다. (→ rules/autonomous_workflow.md)

## 브랜치
- \`main\`: 개발 작업
- \`stable\`: 안정 버전 (사용자 명시 명령 + CI 통과 시에만 merge)
MD

# ── git 초기화 (main / stable) ───────────────────────────────────────
if command -v git >/dev/null 2>&1; then
  (
    cd "$DEST"
    git init -q
    git symbolic-ref HEAD refs/heads/main 2>/dev/null || true
    # pre-commit 훅 활성화(비밀정보 차단) — cwd 독립적으로 .git/hooks 에 설치 + 버전관리용 .githooks 도 유지
    if [[ -f .githooks/pre-commit ]]; then
      cp .githooks/pre-commit .git/hooks/pre-commit
      chmod +x .git/hooks/pre-commit
      git config core.hooksPath .githooks 2>/dev/null || true
    fi
    git add -A
    git -c user.name="setup" -c user.email="setup@local" commit -q -m "chore: initialize project skeleton" || true
    git branch stable 2>/dev/null || true
  )
  echo "  · git init 완료 (main, stable 브랜치)"

  # ── GitHub 연동 (gh CLI, private 리포 생성 + 자동 푸시) ─────────────
  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    (
      cd "$DEST"
      if gh repo create "$NAME" --private --source=. --remote=origin --push; then
        git push -q -u origin stable 2>/dev/null || true
        echo "  · GitHub private 리포 생성 + 푸시 완료 (main, stable)"
      else
        echo "  · GitHub 리포 생성 실패 — 로컬은 정상, 수동으로 연결하세요" >&2
      fi
    )
  else
    echo "  · gh 미설치/미인증 — GitHub 연동 건너뜀 ('gh auth login' 후 재시도)"
  fi
else
  echo "  · git 미설치 — git 초기화 및 GitHub 연동 건너뜀"
fi

echo "✅ 완료: $DEST"
echo "   - 복사: rules/, .claude/(hooks·agents·commands·settings.json), tools/, tests/, .github/(CI), .githooks/(pre-commit)"
echo "           spec.template.yaml, pyproject.toml, Makefile, .env.example, .pre-commit-config.yaml, .gitignore, .gitattributes, .editorconfig"
echo "   - 자율 실행: make setup → spec.template.yaml 을 spec.yaml 로 작성 → /autoloop (golden data 기반 반복)"
echo "   - git pre-commit(비밀정보 차단) 활성화됨"
echo "   - 생성: CLAUDE.md, README.md, docs/ logs/ src/"
echo "   - settings.local.json(권한) 은 복제하지 않음 — 프로젝트별로 Claude Code 가 자동 생성·관리"
echo "   - mcp/ 는 전역($GLOBAL_DIR/mcp/) 을 참조하세요."
