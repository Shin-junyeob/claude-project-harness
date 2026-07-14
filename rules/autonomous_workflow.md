# 자율 실행 워크플로 (autonomous golden-data loop)

사람이 매 턴 개입하지 않고, **명세(spec) + golden data**를 근거로 결과물이 목표에 도달할 때까지
스스로 반복하는 절차다. 입력은 `spec.yaml`, 판정 오라클은 `tools/evaluate.py`, 학습 근거는 `logs/`.

이 루프는 **자동화 폴더(`subproject/` 복제본) 안에서** 실행한다. `src/`·`outputs/`·`logs/`·`spec.yaml`
은 모두 그 폴더 기준이고, `venv/`·`tools/` 는 상위 팀 루트(`../`)와 공유한다(→ [project_structure.md](project_structure.md)).
아래의 `make setup`/`make run`/`make eval` 은 자동화 폴더의 Makefile 이 팀 루트의 `../venv`·`../tools` 로
연결해 주므로, 자동화 폴더에서 그대로 호출하면 된다.

## 입력 계약
- `spec.yaml` — `spec.template.yaml` 을 복사해 작성한다. (→ [project_structure.md](project_structure.md))
  - `produce.command` / `produce.output_path` — 결과물을 생성하는 명령과 산출 경로
  - `golden.path` / `golden.compare` / `golden.threshold` — 정답 데이터와 비교 방식
  - `max_iterations` — 최대 시도 횟수(무한루프 방지)

## golden.mode — 두 가지 사용처
- **reproduce** (기본): 고정된 1회성 산출물 재현. `output_path` 를 `golden.path` 와 비교.
- **generalize**: 변하는 입력을 처리하는 **생성기**. 최종 판정은 **holdout** 으로만 한다
  (`produce.holdout_output_path` 를 `golden.holdout_path` 와 비교). 이는 오라클 게이밍을 막는다.

## 콜드스타트 (0회차)
복제 직후엔 실행 환경도 구현도 없어 첫 `produce.command` 가 실패한다. 루프 진입 전에 **반드시**:
1. **환경 부트스트랩**: `make setup` (팀 공용 venv 생성 + 의존성 설치, pyyaml 포함 — 팀 루트에 venv 가 없을 때 1회). 이후 produce·evaluate 는 **모두 같은 인터프리터**(팀 공용 `../venv/bin/python`)를 쓴다 — 평가기는 자동화 폴더에서 `make eval`(= `../venv/bin/python ../tools/evaluate.py <spec>`)로 호출(bare `python` 금지).
2. **최소 구현 작성**: `spec.description`/`structure` 를 읽고 `src/` 에 결과물을 생성하는 골격 코드를 만든다.
3. 그 다음 produce→evaluate→fix 루프로 들어간다.

## 컨텍스트 체크포인트 (긴 루프 필수)
루프가 길어지면 컨텍스트가 compact 되어 진행 맥락을 잃을 수 있다. 이를 막기 위해:
- **매 시도(iteration)마다** `logs/CHECKPOINT.md` 를 갱신한다(한 일·다음 할 일·핵심 결정·현재 최고 score).
- compact/재시작 직후에는 **`logs/CHECKPOINT.md` → `spec.yaml` → `logs/iterations.md` 순으로 재읽기**한 뒤 그 지점부터 이어간다.
- 규칙: [context_management.md](context_management.md). (대화에 의존하지 말고 디스크 상태를 진실의 출처로 삼는다.)

## 루프 (produce → evaluate → fix)
1. **produce**: `spec.produce.command` 실행 → 결과물 생성.
2. **evaluate**: 자동화 폴더에서 `make eval` (= `../venv/bin/python ../tools/evaluate.py spec.yaml`) 실행.
   - 종료코드 **0 = 통과(완료)**, 1 = 불일치, 2 = 설정 오류.
   - 판정/diff 는 `logs/eval/latest.json` 과 `logs/iterations.md` 에 기록된다.
3. **fix**: 통과가 아니면 `logs/eval/latest.json`(diff)과 `logs/iterations.md`(과거 시도)를 읽고,
   - 무엇이 왜 틀렸는지 가설을 세우고
   - `src/` 코드를 수정한 뒤
   - 시도 내용을 `logs/iterations.md` 에 한 단락으로 기록한다.
4. evaluate 가 통과(exit 0)하거나 `max_iterations` 도달까지 1~3 을 반복한다.

## logs 기록 형식
- `logs/eval/latest.json` — 최신 판정(result/score/detail). evaluate.py 가 자동 작성.
- `logs/iterations.md` — 시도 이력. evaluate.py 가 한 줄 요약을 append 하고,
  수정 주체(에이전트/사람)는 아래 형식으로 시도 단락을 추가한다:
  ```
  ## 시도 N — <한 줄 요약>
  - 가설: 왜 틀렸다고 보는가
  - 변경: 어떤 파일/로직을 어떻게 바꿨는가
  - 판정: PASS/FAIL score=...
  - 다음: 다음에 무엇을 시도할지
  ```

## 게이밍 금지 (오라클 신뢰성)
사람 견제가 빠진 자율 루프는 "golden 을 만족하는 생성기"가 아니라 "golden 을 복사하는 최단 경로"로
수렴하기 쉽다. 다음을 **금지**한다:
- golden 데이터(또는 그 일부)를 `src/` 에 복사·하드코딩해서 통과시키기
- 평가기(`tools/evaluate.py`)를 수정·우회하거나, 비교를 무력화하기
- **generalize 모드에서 holdout golden(`golden.holdout_path`)을 fix 단계가 열람**하기
일반화가 목표라면 `golden.mode: generalize` 로 두어, 최종 PASS 를 학습에 쓰지 않은 holdout 으로만 판정한다.

## 완료 조건 / 폴백
- **완료**: `tools/evaluate.py` 가 exit 0.
- **golden 미지정**: 결과물이 `output_path` 에 생성되고 `acceptance` 항목을 만족하면 완료로 본다.
- **중단(폴백)**: `max_iterations` 도달 시 멈추고, `logs/iterations.md` 에 미해결 사유와
  가장 근접했던 시도(최고 score)를 남긴다. (→ [doc_update_rules.md](doc_update_rules.md))

## 시작하는 법
- 슬래시 커맨드 `/autoloop` (→ `.claude/commands/autoloop.md`) 또는 ralph/autopilot 로 이 루프를 구동한다.
