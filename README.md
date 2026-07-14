# Claude Project Harness

부서(팀) 자동화 저장소의 **공통 뼈대(금형)** 를 한 번의 명령으로 찍어내는 하네스입니다.
규칙·안전장치(훅)·CI·자율 실행 루프를 미리 갖춰두고, `./new-project.sh <팀명>` 으로 팀 저장소에 복제합니다.

**구조: 팀=저장소, 자동화=폴더.** 팀 루트에는 공용 자원(규칙·도구·toolchain)과 `subproject/` 템플릿이
있고, 자동화를 하나 시작할 때마다 `subproject/` 를 복제합니다(`팀/자동화/src` 구조). 코드·결과물·로그는
자동화 폴더에 격리되고, venv·tools·rules 는 팀 루트에서 공유합니다. (→ `rules/project_structure.md`)

> 📖 시각화된 상세 가이드: **`new-project-guide.html`** (브라우저로 열기, 외부 의존 없음)

## 빠른 시작 (다른 로컬에서)
```bash
git clone <this-repo> harness && cd harness
./new-project.sh myteam          # 팀 저장소 + subproject 템플릿 생성 + git(main/stable) + pre-commit + (gh 있으면) GitHub 연동
cd myteam
make setup                       # 팀 공용 venv + 의존성 (최초 1회)
cp -r subproject myautomation    # 자동화 시작마다 템플릿 복제 (팀 루트 바로 아래)
cd myautomation
# spec.yaml 작성(이미 복사돼 있음) → Claude Code 에서:  /autoloop   # golden 에 도달할 때까지 자동 반복
```

## 무엇이 들어있나
| 영역 | 위치 | 내용 |
|------|------|------|
| 규칙 | `rules/` | 코딩·구조·워크플로·커밋(영어)·자율실행·컨텍스트 관리·문서갱신 |
| 안전장치 | `.claude/hooks/` | 위험명령·repo삭제·stable CI게이트·커밋메시지·민감경로·src강제 차단 + 로그 |
| 에이전트 | `.claude/agents/` | planner · implementer · validator · doc-updater |
| 자율 루프 | `tools/evaluate.py`, `spec.template.yaml`, `.claude/commands/autoloop.md` | golden data 기반 produce→evaluate→fix 반복 |
| 품질 | `.github/workflows/ci.yml`, `.githooks/pre-commit`, `pyproject.toml`, `Makefile` | CI·비밀스캔·린트·테스트 |
| MCP | `mcp/.mcp.json` | github·notion (토큰은 환경변수 `${GITHUB_MCP_PAT}` 참조 — 저장소엔 토큰 없음) |

## 환경변수 (토큰)
저장소에는 토큰을 포함하지 않습니다. GitHub MCP 를 쓰려면 로컬에서:
```bash
export GITHUB_MCP_PAT="$(gh auth token)"   # 또는 PAT
```
`.env.example` 을 `.env` 로 복사해 채우세요(`.env` 는 커밋되지 않음).

## 라이선스 / 주의
이 저장소는 **하네스(템플릿)** 만 담습니다. 개인 권한 파일(`.claude/settings.local.json`)과 런타임 상태(`.omc/`)는 `.gitignore` 로 제외됩니다.
