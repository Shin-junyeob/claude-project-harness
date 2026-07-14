# autoloop(자체 자동화 프로세스) vs Ralph — 비교와 하이브리드 분석

> 작성일: 2026-06-18
> 대상: 이 하네스의 자율 실행 루프(`rules/autonomous_workflow.md`, `tools/evaluate.py`, `spec.yaml`,
> `/autoloop`)와 OMC `ralph` 스킬의 비교, 그리고 둘을 결합한 하이브리드 운용 설계.

---

## 0. 한 줄 요약
둘 다 "대화가 아니라 **외부 진실의 출처**에 도달할 때까지 자동 반복"하는 지속 루프다.
다만 **진실을 무엇으로 삼느냐**가 다르다 — autoloop은 **golden 데이터(객관 diff)**, Ralph는
**리뷰어 에이전트(LLM 판단)**. 그래서 둘은 경쟁재가 아니라 **보완재**다: autoloop은 정답이 있는
산출물에 강하고, Ralph는 정답이 없는 코드 작업에 강하다. 하이브리드의 핵심은
**객관 게이트(autoloop) + 주관 품질 게이트(Ralph)를 층으로 쌓는 것**이다.

---

## 1. 비교

### 1.1 한눈에

| 축 | autoloop (자체) | Ralph (OMC) |
|----|----------------|-------------|
| 완료 오라클 | `tools/evaluate.py` — 결과물 vs **golden** 비교(exit 0/1/2) | **리뷰어**(architect/critic/codex)가 acceptance criteria 판정 |
| 입력 계약 | `spec.yaml`(produce.command·output_path·golden.path·compare·threshold) | `prd.json`(user story + acceptance criteria) |
| 작업 단위 | 결과물 1개(재현/생성) | user story 여러 개 |
| 루프 | produce → evaluate → fix | pick story → implement → verify → 다음 → 리뷰 → deslop → 회귀재검 |
| 실행 모델 | 단일 산출물 중심(대체로 순차) | ultrawork 병렬 fan-out + 모델 티어링(haiku/sonnet/opus) |
| 학습 근거 | `logs/eval/latest.json`(diff) + `logs/iterations.md` | `progress.txt` + session-scoped state |
| 컨텍스트 유지 | `logs/CHECKPOINT.md` 재읽기 | `progress.txt` + `.omc/state` |
| 종료 조건 | evaluate exit 0 또는 `max_iterations` | 전 스토리 passes:true + 리뷰 승인 |
| 사후 정리 | (stable merge 시 CI 게이트) | deslop(ai-slop-cleaner) + 회귀 재검 + cancel |
| 게이밍 방어 | **구조적**(holdout 분리, golden 하드코딩/평가기 우회 금지) | 리뷰어 판단에 의존 |
| 안전장치 | 훅(위험명령·src강제·stable게이트·커밋검사) | 정책 수준(스코프 축소 금지 등) |
| 생태계 의존 | 없음(자체 파이썬 + make + 훅) | OMC 상태파일·스킬·에이전트 |

### 1.2 본질적 차이 3가지

1. **완료를 누가 판정하나 — 데이터 diff vs LLM 리뷰어**
   - autoloop: 정답(golden)이 있는 작업에 강함. 산출물을 golden과 바이트/텍스트/유사도로 비교해
     exit code로 못 박으므로 **객관·재현 가능·게이밍 어려움**. 정형 보고서·집계 출력 자동화에 최적.
   - Ralph: 정답 파일이 없는 열린 코드 작업에 강함. criteria를 리뷰어가 판정 — 유연하지만
     **LLM 판단이라 주관·비용·비재현성**이 끼고, 판정자 신뢰가 곧 완료 신뢰.

2. **오라클 게이밍 방어**
   - autoloop은 이를 **명시적으로 설계**(holdout golden을 fix 단계가 못 보게 차단, golden을 src에
     하드코딩 금지, 평가기 수정·우회 금지). "정답 베끼기"로 통과하는 경로를 구조적으로 막음.
   - Ralph는 이를 **리뷰어의 실력/지시**에 의존(강제 데이터 분리는 없음).

3. **작업 분해와 병렬성**
   - autoloop: 산출물 1개 목표의 단일 루프 — 단순·추적 용이.
   - Ralph: PRD로 여러 스토리를 쪼개 executor를 동시에 fan-out — 규모 큰 다중 기능 구현에 빠름.

### 1.3 서로의 빈틈
- **autoloop의 약점:** golden을 만들 수 없는 작업(리팩터링, "코드 품질 좋게", 신규 기능 설계)엔
  오라클이 없다. **코드 품질**(slop·가독성·유지보수성)을 보는 단계가 없다.
- **Ralph의 약점:** 정답 데이터가 있는 일도 리뷰어 판단에 맡겨 **객관성·재현성↓**, holdout 같은
  **일반화/과적합 방어가 약함**. OMC 생태계 의존.

---

## 2. 하이브리드 — 어떻게 결합하나

핵심 통찰: **autoloop = 정확성의 객관 게이트, Ralph = 품질/일반화의 주관 게이트.**
두 게이트를 *층*으로 쌓되, "정확성"은 항상 객관 게이트가 먼저 책임지게 한다.

### 패턴 A — evaluate.py를 Ralph 스토리의 acceptance gate로 (가장 권장)
Ralph의 약한 고리(완료 오라클이 주관적)를 객관화한다.
- 데이터 산출 스토리의 acceptance criterion에 **`make eval` exit 0 (golden 일치)**를 박는다.
- 그러면 **정확성은 evaluate.py가 객관 판정**, 리뷰어는 데이터 diff가 못 보는 것(코드 품질·
  최적성·엣지케이스·일반화)만 판정 → 역할이 깔끔히 분리된다.
- prd.json 예:
  ```json
  {
    "id": "US-003",
    "title": "월간 집계 리포트 생성기",
    "acceptanceCriteria": [
      "make eval 이 exit 0 (outputs/result.json == golden, threshold 충족)",
      "generalize 모드: holdout 입력으로도 make eval exit 0",
      "src/ 에 golden 값이 하드코딩되어 있지 않다(리뷰어 확인)",
      "ruff/pytest 통과"
    ]
  }
  ```

### 패턴 B — autoloop 완료 후 품질 게이트 1회 (autoloop 주도)
autoloop을 주 루프로 두고, **evaluate exit 0 직후** 품질 단계를 덧붙인다.
1. `make eval` PASS 확인(정확성 확정).
2. 변경된 `src/` diff에 대해 리뷰어(architect/critic) 1회 + `ai-slop-cleaner` 스킬 실행(품질·slop).
3. 정리(deslop)가 산출물을 바꿨을 수 있으니 **`make eval` 재실행(회귀 재검)** → 여전히 exit 0이어야 완료.
- "데이터는 맞지만 코드가 엉망/과적합"인 경우를 잡는다.

### 패턴 C — 2단 오케스트레이션 (Ralph가 분해, autoloop이 데이터 스토리 실행)
> 주의: Ralph와 autoloop은 서로를 함수처럼 호출하는 API가 아니다. 둘 다 **Claude 세션이 운용하는
> 프로세스/슬래시 스킬**이고, "결합"은 **공유 컨벤션 + 규율**(예: prd.json criterion = `make eval exit 0`)을
> Claude가 일관되게 적용하는 것이다. 턴키 프로그램 연동을 기대하지 말 것.

큰 자동화를 Ralph가 스토리로 분해 →
- **데이터 스토리**(정답 있음): autoloop에 위임(produce→evaluate→fix until golden).
- **코드/인프라 스토리**(정답 없음): Ralph executor 병렬 처리.
- 마지막에 Ralph 리뷰어 + deslop + 회귀 재검으로 마감.

### 권장 의사결정 규칙
| 상황 | 권장 |
|------|------|
| 정답 산출물 재현/생성, 품질 민감도 낮음 | **autoloop 단독**(가장 싸고 객관적) |
| 정답 산출물인데 코드 품질·일반화 중요 | **패턴 B**(autoloop + 완료 후 품질 게이트) |
| 다중 컴포넌트, 일부만 정답 존재 | **패턴 A/C**(Ralph 오케스트레이션 + evaluate.py 게이트) |
| 정답 데이터 없는 순수 코드 기능 | **Ralph 단독** |

---

## 3. 기대 효과

| 효과 | 메커니즘 | 정성/정량 기대 |
|------|----------|----------------|
| **거짓 완료(false done) 감소** | 객관 게이트(exit 0)가 "되어 보임"을 차단 | "should work" 류 자기보고 완료 제거 |
| **과적합/게이밍 감소** | holdout 분리를 하이브리드에서도 유지 | 일반화 목표 작업의 신뢰도↑ |
| **코드 품질↑** | autoloop엔 없던 리뷰어 + deslop 단계 | slop·중복·미사용 코드 정리, 유지보수성↑ |
| **대형 작업 처리량↑** | Ralph 병렬 fan-out + 모델 티어링 | 다중 스토리 wall-clock↓, 비용/정확도 티어 최적화 |
| **감사 추적성↑** | prd.json(스토리) + iterations.md(시도) + eval 로그(판정) | "무엇을·왜·통과근거" 일원화 기록 |
| **재현성↑(정확성 부분)** | 정확성을 LLM이 아닌 deterministic diff가 판정 | 같은 입력→같은 PASS/FAIL |

요약: **정확성은 객관·재현 가능하게, 품질은 리뷰어가 보강**, 규모는 병렬로 흡수.

### 3.1 효과를 어떻게 측정하나 (지표)
"성능향상"을 주장이 아니라 검증 가능한 수치로 만들기 위한 지표:

| 지표 | 정의 | 무엇을 말해주나 |
|------|------|----------------|
| 거짓 완료율 | 완료 선언 후 재검에서 깨진 비율 | 객관 게이트가 false done을 막는지 |
| 회귀율 | deslop/수정 후 `make eval` 재실패 비율 | 4.4 핑퐁·동작보존 실패 빈도 |
| 과적합 갭 | (train PASS율 − holdout PASS율) | 게이밍/과적합 신호(클수록 나쁨) |
| PASS까지 이터레이션 수 | 스토리당 produce→eval 반복 횟수 | 루프 효율·thrash 여부 |
| deslop 편집량 + 품질 델타 | 정리 줄 수, lint/복잡도 전후 차 | 품질 게이트의 실제 기여 |
| **검증된 완료당 비용** | (토큰+시간) ÷ 리뷰어 승인+eval PASS 건수 | **하이브리드 트레이드오프의 종합 지표** |

마지막 행(검증된 완료당 비용)이 "하이브리드를 켤 가치가 있나"에 직접 답한다 — 비용이 올라도
거짓 완료·회귀·과적합이 충분히 줄면 *검증된 완료당 비용*은 내려간다.

---

## 4. 문제가 발생할 수 있는 변수 상황 (리스크 분석)

> 하이브리드는 게이트가 둘이 되면서 "두 진실의 출처" 문제가 생긴다. 아래는 발생 가능한 변수와 완화책.

### 4.1 오라클 충돌 — 이중 진실의 출처
- **증상:** evaluate.py는 PASS인데 리뷰어는 reject(또는 반대).
- **원인:** 정확성과 품질을 한 게이트가 동시에 판정하려 함.
- **완화:** 역할을 분리·서열화한다. **정확성=evaluate.py가 필요조건(반드시 exit 0)**,
  **품질=리뷰어가 추가 필요조건**. 둘 다 통과해야 완료. 리뷰어가 "정확성"을 뒤집지 못하게,
  리뷰어 프롬프트에서 *정확성 판정은 evaluate.py 소관*임을 명시.

### 4.2 golden 부재 라우팅 오류
- **증상:** 정답 없는 코드 스토리에 `make eval` 기준을 붙여 영원히 FAIL.
- **완화:** 스토리를 **데이터 스토리 / 코드 스토리**로 태깅하고 게이트를 분기. spec의
  `golden.path` 가 비면 "생성 여부 + acceptance"만 보는 기존 폴백을 활용.

### 4.3 게이밍의 이동(squeezing the balloon)
- **증상:** evaluate.py 단독 게이트면 golden을 src에 하드코딩, 리뷰어 단독 게이트면 과적합을 승인.
- **완화:** **두 게이트 동시 적용** + holdout 규율 유지 + 리뷰어에게 "golden 하드코딩/평가기 우회
  여부"를 명시 점검 항목으로 부여(패턴 A 예시의 3번 criterion).

### 4.4 deslop이 golden을 깨뜨림 (가장 흔한 회귀)
- **증상:** PASS 이후 ai-slop-cleaner가 src를 정리 → 산출물이 미세 변경 → eval FAIL.
- **위험:** deslop ↔ re-eval 핑퐁(무한 정리/실패).
- **완화:** deslop은 **동작 보존 변경만** 허용(스코프=변경 파일 한정), 정리 후 **반드시 `make eval`
  회귀 재검**, 1회 깨지면 정리 롤백. 핑퐁 방지용 **정리 시도 횟수 상한**(예: 1~2회) 설정.

### 4.5 비용/지연 폭증
- **증상:** 병렬 executor + 리뷰어 + deslop + 재eval 로 토큰/시간이 단순 작업 대비 수 배.
- **완화:** **복잡도 스위치** — 단순 데이터 작업은 autoloop 단독, 품질·규모 임계 초과 시에만
  하이브리드 발동(2.4 의사결정 규칙). 전역 **토큰/이터레이션 예산 캡** 설정.

### 4.6 상태/도구 충돌
- **증상:** Ralph(`.omc/state` session-scoped `prd.json`)와 autoloop(`spec.yaml`/`logs/`)가 서로
  다른 상태계를 가져 진행상태가 어긋남.
- **완화:** 책임 분리 — **prd.json=팀 루트(오케스트레이션 계층)**, **spec.yaml=각 자동화 폴더
  (subproject 복제본, 실행 계층)**. 병렬 시 세션 ID로 prd 격리(`--plan-id`).

### 4.7 훅 마찰 (이 하네스 특유)
- **증상:** Ralph executor의 병렬 쓰기/ deslop 삭제가 `enforce_src_layout`·`block_repo_delete`·
  `block_dangerous_commands` 훅에 막힘(이번 세션에서도 `rm /mnt/c/...` 가 차단된 사례).
- **완화:** 코드는 자동화 폴더의 `src/`에만(경로에 `src` 포함 → 훅 통과). 병렬 쓰기는 **worktree
  격리**로 충돌 방지. 삭제/정리는 상대경로·스코프 한정으로 위험경로 패턴을 피함.

### 4.8 리뷰어 비결정성·가용성
- **증상:** codex/architect 미가용 또는 동일 입력에 다른 판정 → 완료 재현성↓.
- **완화:** **정확성은 evaluate.py가 보유**(리뷰어는 품질만) → 리뷰어가 흔들려도 정확성은 고정.
  리뷰어 티어 고정, 미가용 시 architect 단독 폴백(절대 블로킹 금지).

### 4.9 종료 정책 불일치 (max_iterations vs "boulder never stops")
- **증상:** autoloop은 `max_iterations`로 멈추는데 Ralph는 멈추지 않으려 함 → 런어웨이 비용.
- **완화:** **전역 정지 조건**을 상위에 둔다 — 스토리별 `max_iterations` + 런 전체 예산/시간 캡 +
  "동일 이슈 3회 반복 시 사람에게 에스컬레이션".

### 4.10 PRD 스코프 크리프
- **증상:** Ralph가 실행 중 발견한 스토리를 무한 추가 → 종료가 멀어짐.
- **완화:** 스토리 추가에 예산 가드, 신규 스토리는 "원 작업 범위 내"로 제한, 범위 밖은 별도 백로그.

### 4.11 holdout 누출
- **증상:** progress.txt/iterations.md/리뷰어가 읽는 로그를 통해 holdout golden 내용이 fix 단계로 샘.
- **완화:** holdout 경로/내용은 **모든 로그·리뷰어 입력에서 제외**(evaluate.py가 generalize 모드에서
  holdout diff를 로그로 안 흘리는 기존 설계 유지), 리뷰어 프롬프트에 holdout 열람 금지 명시.

### 4.12 subproject 경로/cwd 가정
- **증상:** Ralph는 팀 루트에서 돌고 evaluate.py는 cwd 기준 경로(outputs/logs/golden)를 잡음 →
  잘못된 폴더에서 평가.
- **완화:** Ralph가 데이터 스토리를 위임할 때 **cwd=해당 자동화 폴더**로 고정하고 `make eval` 호출
  (자동화 Makefile이 `../venv`·`../tools`로 연결). 결과물·로그가 그 폴더에 격리됨을 보장.

### 4.13 produce 출력의 비결정성 (golden-diff의 고전적 실패)
- **증상:** `produce.command` 출력이 비결정적(타임스탬프, dict/JSON 키 순서, 부동소수 정밀도,
  병렬 쓰기 순서)이면 **코드 정확성과 무관하게** evaluate.py diff가 PASS/FAIL을 깜빡인다.
  루프가 영원히 thrash 하거나 운으로 PASS 한다. 하이브리드는 이 약점을 autoloop 쪽에서 그대로 상속.
- **위험 가중:** 패턴 A가 `make eval exit 0`을 신뢰 게이트로 격상하므로, 깜빡이는 오라클을
  "진실"로 떠받치게 됨.
- **완화:** 비교 전에 출력을 **정규화/canonicalize**(키 정렬, 타임스탬프 마스킹, 수치 반올림)하거나,
  `compare`/`threshold`를 의도적으로 설정. 단 `threshold < 1.0`은 **"문턱 바로 위에서 멈추는" 게이밍**을
  부르므로, 임계 사용 시 holdout 동시 적용으로 견제.

### 4.14 golden 노후화 (객관 게이트가 객관적으로 틀려짐)
- **증상:** 실제 요구가 바뀌었는데 golden 파일이 갱신되지 않으면 evaluate.py가 **낡은 정답에 대해**
  계속 exit 0 → **거짓 확신**. 패턴 A로 신뢰를 몰아준 객관 게이트가 객관적으로 틀린 상태가 됨.
- **위험 가중:** 하이브리드는 이 위험을 *증폭*한다 — 정확성을 LLM이 아닌 golden에 위임했기 때문.
- **완화:** golden을 **set-and-forget 아닌 소유·관리 대상**으로 둔다. 요구 변경 시 golden 갱신을
  트리거(예: spec/요구 문서 변경 시 golden 재확인 체크리스트), golden 출처·갱신일 기록.

---

## 5. 이 하네스에 적용하는 구체 방법

1. **prd.json 컨벤션 추가:** 데이터 스토리의 acceptance에 `make eval exit 0` 를 표준 criterion으로.
2. **완료 후 품질 게이트(패턴 B) 명령화:** autoloop의 PASS 직후 (a) 리뷰어 1회 (b) `ai-slop-cleaner`
   를 변경 `src/` diff 한정 실행 (c) `make eval` 회귀 재검 — 이 3단을 `/autoloop` 절차의 선택 단계나
   별도 `rules/` 절차로 추가.
3. **holdout/generalize 규율 유지:** 리뷰어 프롬프트에 holdout 열람 금지 + golden 하드코딩 점검 포함.
4. **예산 가드:** 스토리별 `max_iterations` + 런 전체 토큰/시간 캡 + 3회 반복 에스컬레이션.
5. **계층 분리:** 오케스트레이션(prd.json)=팀 루트, 실행(spec.yaml)=자동화 폴더(subproject 복제본).
6. **복잡도 스위치:** 단순 데이터 작업은 autoloop 단독, 임계 초과 시에만 하이브리드 발동.

---

## 6. 결론
- **정답 산출물 재현/생성** → autoloop이 더 적합·견고(객관 오라클 + 게이밍 방어).
- **정답 없는 코드 기능 구현·검증** → Ralph가 더 적합(분해·병렬·리뷰어·정리).
- **하이브리드의 가치:** Ralph의 주관적 완료를 autoloop의 객관 게이트로 단단히 하고(패턴 A),
  autoloop의 품질 공백을 Ralph의 리뷰어/deslop로 메운다(패턴 B). 단, **두 진실의 출처**가 생기는
  만큼 4장의 변수(오라클 충돌·deslop 회귀·비용·holdout 누출·경로 가정)를 게이트 서열화와 예산
  가드로 통제하는 것이 성패를 가른다.

> 관련 문서: `rules/autonomous_workflow.md`(자율 루프), `rules/project_structure.md`(팀/자동화 구조),
> `tools/evaluate.py`(오라클), `.claude/commands/autoloop.md`(진입점).
