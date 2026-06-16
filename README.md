# Claude Project Harness

새 프로젝트의 **공통 뼈대(금형)** 를 한 번의 명령으로 찍어내는 하네스입니다.
규칙·안전장치(훅)·CI·자율 실행 루프를 미리 갖춰두고, `./new-project.sh <이름>` 으로 새 프로젝트에 복제합니다.

> 📖 시각화된 상세 가이드: **`new-project-guide.html`** (브라우저로 열기, 외부 의존 없음)

## 빠른 시작 (다른 로컬에서)
```bash
git clone <this-repo> harness && cd harness
./new-project.sh myproj          # 공통 세팅 복제 + git(main/stable) + pre-commit + (gh 있으면) GitHub 연동
cd myproj
make setup                       # venv + 의존성
cp spec.template.yaml spec.yaml  # 프로젝트 설명·결과물·golden 경로 작성
# Claude Code 에서:  /autoloop   # 결과물이 golden 에 도달할 때까지 자동 반복
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
