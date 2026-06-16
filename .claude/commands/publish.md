---
description: 하네스를 영어 컨벤션 커밋 메시지로 public 저장소에 동기화(commit + push)
argument-hint: "[커밋 메시지 직접 지정(선택)]"
allowed-tools: Bash
---

하네스 변경을 public 저장소(`claude-project-harness`)에 발행한다. `./publish.sh` 가 추출·스캔·commit·push 를 수행하고, **커밋 메시지는 규칙에 따라 영어로** 작성해 전달한다.

## 절차
1. **변경 파악**: 이번 세션에서 하네스의 무엇을 바꿨는지 정리한다. 불확실하면
   `git -C .publish-workdir fetch -q origin 2>/dev/null && git -C .publish-workdir diff --stat origin/main 2>/dev/null` 로 변경 윤곽을 확인한다(없으면 세션 맥락으로 판단).
2. **커밋 메시지 작성** ($ARGUMENTS 가 있으면 그대로 사용, 없으면 직접 작성):
   - `rules/commit_conventions.md` 준수 — **영어** `type: subject` 형식.
   - 타입: `feat|fix|docs|style|refactor|test|chore` 중 하나.
   - 명령형·소문자 시작·마침표 없음. 한국어 금지. `update code`·`fix bug` 같은 모호한 메시지 금지.
   - 예: `feat: add publish sync command`, `fix: allow .env.example through pre-commit`
3. **발행 실행**: `./publish.sh "<작성한 메시지>"` 실행.
   - 스크립트가 화이트리스트만 추출 → **비밀/사설경로 스캔 게이트** → 변경 있을 때만 commit·push.
   - 스캔 게이트에서 중단되면(누출 의심) **푸시하지 말고** 무엇이 걸렸는지 사용자에게 보고한다.
4. **보고**: 커밋 해시·푸시 여부, 또는 "변경 없음(이미 최신)"을 보고한다.

> 주의: 토큰·회사 데이터·개인설정은 `publish.sh` 가 구조적으로 제외한다. 메시지에 비밀을 넣지 않는다.
