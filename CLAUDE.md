# 전역 작업 디렉토리
> 하위 폴더마다 프로젝트를 진행하는 로컬 전역 디렉토리. 공통 세팅의 원본(source of truth).

---

## 이 파일의 역할
이 파일은 **이정표(경로 지도)** 역할만 한다. 규칙·절차·에이전트 정의를 직접 쓰지 않는다.
이 전역 디렉토리는 모든 하위 프로젝트가 공통으로 갖는 기본 세팅의 원본을 보관한다.
새 프로젝트는 `new-project.sh` 로 생성하며, 공통 세팅이 해당 폴더에 복사된다.

---

## 경로 참조표
| 관심사 | 경로 | 설명 |
|--------|------|------|
| 새 프로젝트 생성 | new-project.sh | 공통 세팅을 복사해 새 프로젝트 폴더 생성 |
| 코딩 컨벤션 | rules/coding_conventions.md | 공통 코딩 규칙 (복사됨) |
| 프로젝트 구조 | rules/project_structure.md | 표준 폴더 구조 (복사됨) |
| 워크플로 | rules/workflow.md | main/stable 브랜치 전략 (복사됨) |
| 자율 실행 | rules/autonomous_workflow.md | spec+golden 기반 produce→evaluate→fix 루프 (복사됨) |
| 컨텍스트 관리 | rules/context_management.md | 외부 체크포인트+재읽기로 긴 루프 컨텍스트 유지 (복사됨) |
| 자율 명세 | spec.template.yaml | 프로젝트별 spec.yaml 입력 계약 (복사됨) |
| 평가기 | tools/evaluate.py | 결과물 vs golden 비교 오라클 (복사됨) |
| 자율 진입점 | .claude/commands/autoloop.md | /autoloop 슬래시 커맨드 (복사됨) |
| 커밋 메시지 | rules/commit_conventions.md | type: subject 영어 커밋 규칙 (복사됨) |
| 저장소 이름 | rules/repo_naming.md | GitHub repo는 knk_<영문팀명>-automation (복사됨) |
| 문서 갱신 | rules/doc_update_rules.md | 문서 갱신 정책 (복사됨) |
| 에이전트 | .claude/agents/ | planner, implementer, validator, doc-updater (복사됨) |
| 훅 | .claude/hooks/ | 접근/위험명령/repo삭제/커밋메시지 차단, src강제, stable CI게이트, 로그 (복사됨) |
| MCP | mcp/ | 전역 전용 MCP 설정 (복사 안 함, 참조) |
| CI | .github/workflows/ci.yml | ruff 린트 + pytest (복사됨, stable CI게이트와 연동) |
| git pre-commit | .githooks/pre-commit | 비밀정보 커밋 차단 + ruff 린트 (복사·init 시 활성화) |
| pre-commit 프레임워크 | .pre-commit-config.yaml | 선택: 표준 pre-commit 훅 (복사됨) |
| 프로젝트 설정 허브 | pyproject.toml | 의존성 + ruff + pytest 설정 통합 (복사됨) |
| 작업 진입점 | Makefile | setup/test/lint/format/run (복사됨) |
| 테스트 | tests/ | pytest 스모크 테스트 스캐폴드 (복사됨) |
| 환경변수 예시 | .env.example | 필요한 env 목록(.env는 커밋 금지) (복사됨) |
| 에디터/줄바꿈 | .editorconfig, .gitattributes | 들여쓰기·LF 정규화 (복사됨) |
| 공통 gitignore | .gitignore | 새 프로젝트로 복사됨 |

---

## 구조 계약
- 전역 루트에는 **항상 공통으로 포함되는 내용만** 쌓는다.
- 상속 방식: **생성 시 복사** (런타임 참조 아님). `new-project.sh` 가 복사.
- 복사 대상(화이트리스트): `rules/`, `.claude/hooks/`, `.claude/agents/`, `.claude/commands/`, `.claude/settings.json`(공통 훅), `tools/`, `tests/`, `.github/`(CI), `.githooks/`(pre-commit), `spec.template.yaml`, `pyproject.toml`, `Makefile`, `.env.example`, `.pre-commit-config.yaml`, `.gitignore`, `.gitattributes`, `.editorconfig`, 그리고 생성물(CLAUDE.md, README.md, docs/ logs/ src/).
- 설정 파일 분리: `settings.json`=훅(복사), `settings.local.json`=권한(복사 안 함). 권한은 디렉토리마다 목록·경로가 다르므로 각 프로젝트에서 Claude Code 가 자동 생성·관리한다. 훅 경로는 절대경로 박제 대신 `$CLAUDE_PROJECT_DIR`(현재 프로젝트 루트로 자동 치환되는 변수)를 써서, 복제된 프로젝트마다 자기 폴더 기준으로 동작하고 작업 디렉토리(cwd) 변화에도 안전하게 한다.
- 복사 제외: `mcp/`(전역 참조), `settings.local.json`(권한), 기존 프로젝트 폴더, 메모리, 개인 파일.
- 새 프로젝트는 git `main`/`stable` 2-브랜치로 운영. stable merge는 사용자 명시 명령 시에만.
