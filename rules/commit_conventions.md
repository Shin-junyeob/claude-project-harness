# Git 커밋 메시지 규칙 (공통)

> 출처: [wikidocs 07.02 Commit 메시지 규칙](https://wikidocs.net/332862) 기반 + **영어 작성** 규칙 추가.

## 기본 형식
```
type: change description
```
- **커밋 메시지는 영어로 작성한다.** (한국어 금지)
- 필요 시 범위를 붙인다: `type(scope): change description`

## Commit 타입
| 타입 | 설명 |
|------|------|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서 수정 |
| `style` | 코드 스타일 수정 (기능 변경 없음) |
| `refactor` | 코드 구조 개선 |
| `test` | 테스트 코드 추가 |
| `chore` | 기타 작업 (빌드 설정 등) |

## 작성 규칙
- **영어로** 작성한다.
- 한 커밋에는 **하나의 작업**만 담는다.
- 제목은 명확하고 간결하게 — 변경 내용이 한눈에 드러나야 한다.
- 제목은 **명령형(imperative)**, 첫 글자 소문자, 끝에 마침표(`.`) 없음.
- 모호한 메시지 금지: `update code`, `fix bug` 처럼 무엇을 했는지 알 수 없는 메시지는 쓰지 않는다.

## 좋은 예 (영어)
```
feat: add login feature
fix: fix login error
docs: update installation guide
refactor: improve authentication logic
```

## 나쁜 예
```
update code            # 무엇을 바꿨는지 불명확
fix bug                # 어떤 버그인지 불명확
로그인 기능 추가         # 한국어 — 영어로 작성해야 함
```

## 강제 (훅)
`check_commit_message` 훅이 `git commit -m` 메시지를 검사한다.
- 허용 타입(`feat|fix|docs|style|refactor|test|chore`)으로 시작하는 `type: subject` 형식이어야 한다.
- 제목에 한글이 있으면 차단한다(영어로 작성).
- (→ `.claude/hooks/check_commit_message.py`)
