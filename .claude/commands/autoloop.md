---
description: spec.yaml 을 읽어 결과물이 golden 과 일치할 때까지 자율 반복(produce→evaluate→fix)
argument-hint: "[spec 파일경로] (기본 spec.yaml)"
allowed-tools: Bash, Read, Write, Edit
---

`rules/autonomous_workflow.md` 절차에 따라 자율 실행 루프를 구동한다.
명세 파일: `$ARGUMENTS` (없으면 `spec.yaml`).

## 절차
1. **명세 로드**: 명세 파일을 읽는다. 없으면 사용자에게 `spec.template.yaml` 복사를 안내하고 중단.
   - `produce.command`, `produce.output_path`, `golden.path/compare/threshold`, `max_iterations` 확인.
1.5. **콜드스타트**:
     - **환경 부트스트랩**: `make setup` (venv + 의존성, pyyaml 포함). 이후 모든 실행은 `venv/bin/python` 사용.
     - `src/` 가 비었으면 `spec.description`/`structure` 기반 최소 골격을 작성해 `produce.command` 가 결과물을 만들 수 있게 한다.
2. **루프** (최대 `max_iterations` 회):
   a. `produce.command` 실행 → 결과물 생성.
   b. `make eval` (= `venv/bin/python tools/evaluate.py <명세파일>`) 실행. 종료코드 0 이면 **완료**. (bare `python` 금지)
   c. 0 이 아니면 `logs/eval/latest.json`(diff)·`logs/iterations.md`(과거 시도)를 읽고,
      틀린 원인 가설 → `src/` 수정 → 시도 단락을 `logs/iterations.md` 에 기록 → (a) 로 반복.
3. **완료**: evaluate exit 0 또는 (golden 미지정 시) 결과물 생성 + `acceptance` 충족.
   결과 요약(최종 score, 변경 파일, 시도 횟수)을 보고한다.
4. **중단**: `max_iterations` 도달 시, 미해결 사유와 최고 score 시도를 `logs/iterations.md` 에 남기고 보고.

## 규칙
- 한 번에 결과물을 통째로 바꾸려 하지 말고, diff 가 가리키는 가장 큰 불일치부터 줄여나간다.
- 매 시도를 반드시 `logs/iterations.md` 에 기록한다(다음 시도가 과거를 근거로 학습하도록).
- 테스트를 지워 통과시키거나 평가기를 우회하지 않는다.
- **게이밍 금지**: golden 을 `src/` 에 복사·하드코딩하지 않는다. generalize 모드에서 holdout golden 은 열람 금지.
  일반화가 목표면 `golden.mode: generalize` 로 holdout 판정한다. (→ rules/autonomous_workflow.md)
- 큰 작업은 ralph/autopilot 로 위임해 지속 실행할 수 있다.
