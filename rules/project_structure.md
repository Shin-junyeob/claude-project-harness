# 프로젝트 구조 (공통)

부서(팀)별로 git 저장소 1개를 두고, 그 안에서 **자동화 1개당 폴더 1개**로 운영한다.
공용 자원(규칙·도구·toolchain)은 팀 루트에서 공유하고, 코드·결과물·로그는 자동화 폴더에 격리한다.

```
<팀명>/                         # = git 저장소 1개 (부서 단위)
├── CLAUDE.md                   # 이정표(경로 지도)만. 규칙·절차를 직접 쓰지 않는다.
├── README.md                   # 팀 개요·사용법
├── .gitignore
├── .claude/
│   ├── agents/                 # 에이전트 역할·입출력·도구 정의 (.md)
│   ├── hooks/                  # 훅 실행 스크립트
│   └── settings.local.json     # 훅 등록, 권한 정책(프로젝트별 자동 생성)
├── rules/                      # 코딩 컨벤션, 도메인 규칙 (공용)
├── tools/                      # evaluate.py 등 공용 도구
├── pyproject.toml              # 공용 의존성·ruff·pytest 설정
├── Makefile                    # 공용 toolchain: setup/lint/format/test/clean
├── spec.template.yaml          # 자동화 spec 원본
├── venv/                       # 공용 가상환경 (make setup 시 생성)
└── subproject/                 # 자동화 템플릿 — 새 자동화마다 복제해서 사용
    ├── CLAUDE.md               # 자동화 이정표(상위 팀 규칙 참조)
    ├── Makefile                # ../venv·../tools 공유 (run/eval/lint/test)
    ├── spec.yaml               # 자동화 입력 계약(spec.template.yaml 복사본)
    ├── src/                    # 구현 코드
    ├── outputs/                # 결과물
    ├── docs/                   # 설계·명세
    └── logs/                   # 에러·이터레이션 이력, CHECKPOINT.md
```

새 자동화 시작: `cp -r subproject <자동화명>` (팀 루트 **바로 아래**에 둔다 — 자동화 Makefile 이
`../venv`·`../tools` 를 참조하기 때문). 최종 구조는 `팀/자동화/src/` 형태가 된다.

## 어디에 무엇을 두나

**팀 루트 (공용 — 자동화끼리 공유)**

| 폴더/파일 | 저장 내용 |
|-----------|-----------|
| `.claude/agents/` | 에이전트 역할·입출력·도구 정의 |
| `.claude/hooks/` | 훅 실행 스크립트 |
| `rules/` | 코딩 컨벤션, 접근 정책, 도메인 규칙 |
| `tools/` | 평가기(`evaluate.py`) 등 공용 도구 |
| `pyproject.toml` · `Makefile` · `venv/` | 공용 toolchain(의존성·린트·테스트) |
| `spec.template.yaml` | 자동화 spec 의 원본 템플릿 |

**자동화 폴더 (`subproject/` 복제본 — 자동화별 격리)**

| 폴더/파일 | 저장 내용 |
|-----------|-----------|
| `src/` | 구현 코드 |
| `outputs/` | produce 결과물 |
| `docs/` | 아키텍처 설계, 명세, 워크플로 |
| `logs/` | 실패·에러 기록, 이터레이션 이력, `CHECKPOINT.md` |
| `spec.yaml` | 이 자동화의 입력 계약 |

## 실행 위치
- 결과물 생성/평가/`/autoloop` 은 **자동화 폴더 안에서** 실행한다(`make run`, `make eval`).
  평가기가 cwd 기준으로 outputs·logs·golden 경로를 잡으므로, 자동화별로 로그·결과물이 격리된다.
- `make setup`(공용 venv 생성)은 팀 루트의 toolchain 을 쓴다. 자동화 폴더에서 실행해도 팀 루트로 위임된다.

## 금지 사항
- 구현 코드를 자동화 폴더의 `src/` 이외 경로에 두는 것 (`tools/`·`tests/` 는 예외)
- CLAUDE.md에 규칙·절차를 직접 작성하는 것 (CLAUDE.md는 이정표만)
- 에이전트 정의를 CLAUDE.md나 `rules/`에 작성하는 것 (반드시 `.claude/agents/`에)
- 에러 발생 시 `logs/`에 기록하지 않고 넘어가는 것
- 자동화 폴더를 팀 루트 바로 아래가 아닌 곳에 두는 것 (`../venv`·`../tools` 경로가 깨짐)

## mcp 참조
- MCP 설정은 각 팀 폴더에 복사하지 않는다. 전역 디렉토리의 `mcp/`를 참조한다.
