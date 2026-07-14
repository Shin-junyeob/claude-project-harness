#!/usr/bin/env bash
#
# new-project.sh — 전역 디렉토리의 공통 세팅을 새 "팀(부서) 폴더"로 복사한다.
#
# 사용법:  ./new-project.sh <팀명> [GitHub-repo명]
#
# 구조(팀 = git 저장소 1개, 자동화 = subproject 폴더 1개):
#   <팀명>/
#   ├── (공용) rules/ .claude/ tools/ .github/ .githooks/ pyproject.toml Makefile
#   │         spec.template.yaml .gitignore .gitattributes .editorconfig .env.example ...
#   ├── CLAUDE.md / README.md            # 팀 이정표
#   └── subproject/                      # 자동화 템플릿 — 새 자동화마다 이 폴더를 복제해 사용
#       ├── src/ outputs/ docs/ logs/    # (코드·결과물·문서·로그가 자동화별로 격리됨)
#       ├── spec.yaml                    # spec.template.yaml 복사본(자동화별 입력 계약)
#       ├── Makefile                     # 팀 루트의 ../venv·../tools 를 공유하는 실행 진입점
#       └── CLAUDE.md                    # 자동화별 이정표(상위 팀 규칙 참조)
#
# 동작:
#   - 팀 루트에 공용 항목 복사 + git init(main/stable) + (gh 있으면) GitHub private 연동
#   - subproject/ 템플릿 1개 생성. 자동화를 시작할 때:  cp -r subproject <자동화명>
#   - 복사 안 함: mcp/(전역 참조), .claude/settings.local.json(프로젝트별 권한 자동관리)
#
set -euo pipefail

# ── 전역 디렉토리 = 이 스크립트가 있는 위치 ──────────────────────────
GLOBAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 인자 검증 ────────────────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
  echo "사용법: $0 <팀명> [GitHub-repo명]" >&2
  exit 1
fi
NAME="$1"
# 경로 구분자·공백·앞쪽 하이픈 등 위험한 이름만 거부 (한글 등 일반 문자는 허용)
if [[ "$NAME" == */* || "$NAME" == *" "* || "$NAME" == .* || "$NAME" == -* || -z "$NAME" ]]; then
  echo "오류: 팀명에 경로 구분자/공백이 있거나 '.' '-' 로 시작합니다: $NAME" >&2
  exit 1
fi

# ── GitHub repo 이름 규칙: knk_<영문팀명>-automation (→ rules/repo_naming.md) ─
#   GitHub repo 명은 ASCII 만 허용한다. 한글 폴더명을 그대로 쓰면 GitHub 가 '-' 로
#   치환하므로, 한글 팀명을 영문으로 매핑해 규칙대로 repo 명을 만든다.
#   2번째 인자로 repo 명을 직접 지정하면 그것을 우선한다.
GH_REPO="${2:-}"
# 회사별 팀명 매핑은 로컬 전용 team_repo_map.sh 에서 가져온다(public 저장소엔 없음).
if [[ -z "$GH_REPO" && -f "$GLOBAL_DIR/team_repo_map.sh" ]]; then
  GH_REPO="$(bash "$GLOBAL_DIR/team_repo_map.sh" "$NAME" 2>/dev/null || true)"
fi
# 매핑 없음: 이름이 유효한 ASCII 면 그대로 사용, 비ASCII 면 비워서 GitHub 건너뜀(— 치환 방지)
if [[ -z "$GH_REPO" ]]; then
  if [[ "$NAME" =~ [^A-Za-z0-9._-] ]]; then GH_REPO=""; else GH_REPO="$NAME"; fi
fi
# ASCII 검증: 허용문자(영문/숫자/_/-/.) 외가 있거나 비면 무효
if [[ -n "$GH_REPO" && "$GH_REPO" =~ [^A-Za-z0-9._-] ]]; then
  echo "오류: GitHub repo 명 '$GH_REPO' 에 허용되지 않는 문자가 있습니다(ASCII 영문/숫자/_/-/. 만)." >&2
  exit 1
fi

DEST="$GLOBAL_DIR/$NAME"
if [[ -e "$DEST" ]]; then
  echo "오류: '$DEST' 가 이미 존재합니다. 덮어쓰지 않습니다." >&2
  exit 1
fi

echo "▶ 새 팀 폴더 생성: $DEST"
mkdir -p "$DEST"

# ── 팀 공용 항목 복사 (자동화끼리 공유하는 것만) ─────────────────────
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

# 하네스 전용 도구는 새 프로젝트에 복제하지 않는다(publish.sh 는 애초에 복사 목록에 없음).
#   /publish 슬래시 커맨드(publish.md)는 .claude/commands 통째 복사로 따라오므로 제거한다.
rm -f "$DEST/.claude/commands/publish.md" "$DEST/publish.sh" 2>/dev/null || true

# ── subproject/ 템플릿 (자동화 1개 = 이 폴더 1개. 새 자동화마다 복제해 사용) ──
SUB="$DEST/subproject"
for d in src outputs docs logs; do
  mkdir -p "$SUB/$d"
  touch "$SUB/$d/.gitkeep"
done

# 자동화별 입력 계약: 팀 공용 템플릿을 subproject 의 spec.yaml 로 복사
cp "$GLOBAL_DIR/spec.template.yaml" "$SUB/spec.yaml"

# 컨텍스트 체크포인트 시드 (→ rules/context_management.md)
cat > "$SUB/logs/CHECKPOINT.md" <<'MD'
# CHECKPOINT — 작업 진행 상태 (compact/재시작 시 가장 먼저 재읽기)

> 마일스톤마다 갱신한다. 대화가 아니라 이 파일이 진실의 출처다.

## <시각/마일스톤>
- 한 일:
- 다음 할 일:
- 핵심 결정·제약:
- 관련 파일:
- (실패 시) 가설:
MD

# subproject 실행 진입점 — 팀 루트(상위 폴더)의 venv·tools 를 공유한다.
#   recipe 들여쓰기는 반드시 TAB. 이 폴더를 복제해 만든 자동화 폴더도 팀 루트 바로 아래에 두어야
#   ../venv, ../tools 상대경로가 맞는다.
cat > "$SUB/Makefile" <<'MK'
# subproject 단위 실행 진입점 — 팀 루트(상위 폴더)의 venv·tools 를 공유한다.
# 새 자동화는 이 폴더를 복제해 만든다:  cp -r subproject <자동화명>
# (복제본은 반드시 팀 루트 바로 아래에 둘 것 — ../venv, ../tools 경로가 맞아야 한다.)
ROOT ?= ..
VENV := $(ROOT)/venv
PY   := $(VENV)/bin/python

.PHONY: setup run eval lint format test
setup:   ## 팀 공용 venv 생성/갱신(팀 루트에서 1회면 충분)
	$(MAKE) -C $(ROOT) setup
run:     ## 결과물 생성(src/main.py 실행 — spec 의 produce.command 에 맞게 교체)
	$(PY) src/main.py
eval:    ## 결과물 vs golden 평가(이 폴더 spec.yaml). 로그·결과물은 이 폴더에 격리된다
	$(PY) $(ROOT)/tools/evaluate.py spec.yaml
lint:    ## ruff 린트(이 폴더)
	$(VENV)/bin/ruff check .
format:  ## ruff 포맷(이 폴더)
	$(VENV)/bin/ruff format .
test:    ## pytest(이 폴더)
	$(VENV)/bin/pytest
MK

# subproject 이정표 (상위 팀 공용 규칙을 참조)
cat > "$SUB/CLAUDE.md" <<'MD'
# subproject (자동화 템플릿)
> 자동화 1개 = 이 폴더 1개. 새 자동화는 이 폴더를 복제해 시작한다: `cp -r subproject <자동화명>`

---

## 이 파일의 역할
이 파일은 **이정표(경로 지도)** 역할만 한다. 규칙·절차는 상위 팀 폴더(`../`)의 공용 자원을 따른다.
코드·결과물·로그는 이 폴더 안에 격리되어 자동화끼리 섞이지 않는다.

---

## 경로 참조표
| 관심사 | 경로 | 설명 |
|--------|------|------|
| 구현 코드 | src/ | 이 자동화의 코드(팀 규칙: 코드는 src/ 에만) |
| 결과물 | outputs/ | produce 결과물 |
| 문서 | docs/ | 이 자동화의 설계·명세 |
| 로그/체크포인트 | logs/ , logs/CHECKPOINT.md | 에러·이력·컨텍스트 |
| 입력 계약 | spec.yaml | 자율 실행 명세(팀 spec.template.yaml 복사본) |
| 실행 진입점 | Makefile | make run/eval/lint/test (팀 ../venv·../tools 공유) |
| 코딩 컨벤션 | ../rules/coding_conventions.md | 팀 공용 규칙 |
| 자율 절차 | ../rules/autonomous_workflow.md | produce→evaluate→fix 루프 |
| 평가기 | ../tools/evaluate.py | 결과물 vs golden 오라클 |
| 자율 진입점 | /autoloop | 이 폴더에서 실행(spec.yaml 기준) |

---

## 구조 계약
- 구현 코드는 이 폴더의 `src/` 에만 둔다.
- 결과물은 `outputs/`, 에러·이력은 `logs/`, 컨텍스트는 `logs/CHECKPOINT.md`.
- 자율 실행: 팀 루트에서 `make setup`(1회) → 이 폴더에서 `cp ../spec.template.yaml spec.yaml`
  은 이미 되어 있으니 내용 작성 → 이 폴더에서 `/autoloop`.
- venv·tools·rules 는 팀 루트(`../`)와 공유한다(자동화마다 중복 생성하지 않음).
MD

# ── 팀 CLAUDE.md (이정표 형식) ───────────────────────────────────────
cat > "$DEST/CLAUDE.md" <<MD
# $NAME
> 부서(팀) 자동화 저장소. 자동화 1개 = \`subproject/\` 복제 폴더 1개.

---

## 이 파일의 역할
이 파일은 **이정표(경로 지도)** 역할만 한다. 규칙·절차·에이전트 정의를 직접 쓰지 않는다.
세부 규칙은 \`rules/\`, 에이전트는 \`.claude/agents/\`, 훅은 \`.claude/hooks/\` 에 둔다.
이 폴더는 팀 단위 git 저장소이며, 그 안에서 자동화별로 \`subproject/\` 를 복제해 운영한다.

---

## 새 자동화 시작
\`\`\`bash
cp -r subproject <자동화명>      # 템플릿 복제(팀 루트 바로 아래에)
cd <자동화명>
# spec.yaml 작성 → /autoloop (또는 make run / make eval)
\`\`\`

## 경로 참조표
| 관심사 | 경로 | 설명 |
|--------|------|------|
| 자동화 템플릿 | subproject/ | 새 자동화마다 복제하는 골격(src·outputs·docs·logs·spec·Makefile) |
| 코딩 컨벤션 | rules/coding_conventions.md | 팀 공용 코딩 규칙 |
| 프로젝트 구조 | rules/project_structure.md | 표준 폴더 구조 |
| 워크플로 | rules/workflow.md | main/stable 브랜치 전략(stable은 CI 통과 시 merge) |
| 커밋 메시지 | rules/commit_conventions.md | type: subject 영어 커밋 규칙 |
| 저장소 이름 | rules/repo_naming.md | GitHub repo는 knk_<영문팀명>-automation |
| 환경변수 | rules/env_management.md | .env는 직접 열지 말고 python-dotenv로 로드, .env.example 기준 |
| 환경변수 | rules/env_management.md | .env는 직접 열지 말고 python-dotenv로 로드, .env.example 기준 |
| 자율 실행 | rules/autonomous_workflow.md | spec+golden 기반 produce→evaluate→fix 루프 |
| 컨텍스트 관리 | rules/context_management.md | 외부 체크포인트+재읽기로 긴 루프 유지 |
| 문서 갱신 | rules/doc_update_rules.md | 문서 갱신 정책 |
| 자율 명세 | spec.template.yaml | subproject/spec.yaml 로 복사되는 입력 계약 원본 |
| 평가기 | tools/evaluate.py | 결과물 vs golden 비교 오라클(자동화 폴더에서 실행) |
| 자율 진입점 | .claude/commands/autoloop.md | /autoloop 슬래시 커맨드(자동화 폴더에서 실행) |
| 팀 작업 명령 | Makefile | make setup/test/lint/format/clean (공용 venv·toolchain) |
| 에이전트 | .claude/agents/ | planner, implementer, validator, doc-updater |
| 훅 | .claude/hooks/ | 접근/위험명령/repo삭제/커밋메시지/.env읽기 차단, src강제, stable CI게이트, 로그 |
| CI | .github/workflows/ci.yml | ruff 린트 + pytest |
| MCP | $GLOBAL_DIR/mcp/ | 전역 MCP 설정 참조(복사 안 함) |

---

## 구조 계약
- **팀 루트** = 공용 자원: \`rules/\` \`.claude/\` \`tools/\` \`.github/\` \`.githooks/\` \`pyproject.toml\`
  \`Makefile\`(toolchain) \`spec.template.yaml\` \`venv/\`(make setup 시 생성). 자동화끼리 공유한다.
- **자동화별 폴더**(\`subproject/\` 복제) = 격리 자원: \`src/\` \`outputs/\` \`docs/\` \`logs/\` \`spec.yaml\`.
  코드·결과물·로그가 폴더 단위로 분리되어 자동화가 늘어도 섞이지 않는다.
- 구현 코드는 각 자동화 폴더의 \`src/\` 에만 둔다(\`tools/\`·\`tests/\` 는 예외).
- 결과물 생성/평가(\`make run\`/\`make eval\`, \`/autoloop\`)는 **자동화 폴더 안에서** 실행한다.
  (평가기가 cwd 기준으로 outputs·logs·golden 경로를 잡으므로 폴더별로 격리된다.)
- 수정은 main 브랜치에서, 안정 버전만 stable 로 merge(사용자 명시 명령 + CI 통과 시).
MD

# ── README.md ────────────────────────────────────────────────────────
cat > "$DEST/README.md" <<MD
# $NAME

## 개요
부서(팀) 자동화 저장소. **자동화 1개 = \`subproject/\` 복제 폴더 1개** 로 운영한다.
공용 설정(rules·tools·venv·CI)은 팀 루트에서 공유하고, 코드·결과물·로그는 자동화 폴더에 격리된다.

## 폴더 구조
- \`subproject/\` 자동화 템플릿(복제해서 사용). 안에 \`src/ outputs/ docs/ logs/ spec.yaml Makefile\`
- \`rules/\` 코딩·도메인 규칙(공용)
- \`tools/\` 평가기 등 공용 도구
- \`.claude/\` 에이전트·훅·설정(공용)
- \`pyproject.toml\` \`Makefile\` 공용 toolchain

## 새 자동화 시작
\`\`\`bash
make setup                    # 팀 공용 venv + 의존성(최초 1회)
cp -r subproject <자동화명>    # 템플릿 복제(팀 루트 바로 아래)
cd <자동화명>
cp ../spec.template.yaml spec.yaml   # 이미 복사돼 있음 — 내용만 작성
make run                      # 결과물 생성
make eval                     # 결과물 vs golden 평가
\`\`\`

## 자율 실행 (golden data 기반 반복)
자동화 폴더 안에서 \`spec.yaml\` 작성 후 Claude Code 에서 \`/autoloop\` 실행 →
결과물이 golden 에 도달할 때까지 produce→evaluate→fix 를 자동 반복. (→ rules/autonomous_workflow.md)

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
    git -c user.name="setup" -c user.email="setup@local" commit -q -m "chore: initialize team skeleton" || true
    git branch stable 2>/dev/null || true
  )
  echo "  · git init 완료 (main, stable 브랜치)"

  # ── GitHub 연동 (gh CLI, private 리포 생성 + 자동 푸시) ─────────────
  if [[ -z "$GH_REPO" ]]; then
    echo "  · GitHub 연동 건너뜀 — repo 명을 규칙대로 정할 수 없습니다." >&2
    echo "    한글 팀명 매핑이 없으면 영문 repo 명을 직접 주세요(규칙: knk_<영문팀명>-automation):" >&2
    echo "    예) ./new-project.sh $NAME knk_<영문팀명>-automation   (→ rules/repo_naming.md)" >&2
  elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    (
      cd "$DEST"
      if gh repo create "$GH_REPO" --private --source=. --remote=origin --push; then
        git push -q -u origin stable 2>/dev/null || true
        echo "  · GitHub private 리포 생성 + 푸시 완료: $GH_REPO (main, stable)"
      else
        echo "  · GitHub 리포 생성 실패($GH_REPO) — 로컬은 정상, 수동으로 연결하세요" >&2
      fi
    )
  else
    echo "  · gh 미설치/미인증 — GitHub 연동 건너뜀 ('gh auth login' 후 재시도)"
  fi
else
  echo "  · git 미설치 — git 초기화 및 GitHub 연동 건너뜀"
fi

echo "✅ 완료: $DEST"
echo "   - 팀 공용 복사: rules/, .claude/(hooks·agents·commands·settings.json), tools/, tests/, .github/(CI), .githooks/(pre-commit)"
echo "                  spec.template.yaml, pyproject.toml, Makefile, .env.example, .pre-commit-config.yaml, .gitignore, .gitattributes, .editorconfig"
echo "   - subproject/ 템플릿 생성(src·outputs·docs·logs·spec.yaml·Makefile·CLAUDE.md)"
echo "   - 새 자동화 시작:  cd $NAME && make setup && cp -r subproject <자동화명> && cd <자동화명> && /autoloop"
echo "   - git pre-commit(비밀정보 차단) 활성화됨"
echo "   - settings.local.json(권한) 은 복제하지 않음 — 프로젝트별로 Claude Code 가 자동 생성·관리"
echo "   - mcp/ 는 전역($GLOBAL_DIR/mcp/) 을 참조하세요."
