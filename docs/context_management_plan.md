# 컨텍스트 유지 전략 플랜 (auto-compact vs 외부 체크포인트)

> 질문: auto-compact를 끄고 400~600K에서 memory 기록 후 compact→재읽기로 이어가는 게 나을까?
> ralph 기본 방식과 비교해 어떻게 하는 게 좋은가.

## 1. 사실 확인 — Claude Code 실제 동작 (공식 문서 기반)
- **트리거**: auto-compact는 **활성 컨텍스트 윈도우 한계에 근접**할 때 발생. 정확한 % 는 공식 미명시(흔히 말하는 ~95%는 비공식). 200K 모델 → ~200K 부근, 1M 모델 → ~1M 부근. → "윈도우 크기 기준으로 트리거"라는 이해는 대체로 맞음.
- **compact 동작**: ① 오래된 도구 출력 제거 → ② 대화를 구조화 요약(원본의 ~12%로 압축). **보존**: 사용자 의도·검토한 파일/핵심 스니펫·오류와 수정·진행 중 작업. **손실**: 상세 도구 출력·중간 추론.
- **비활성화/조정**: `settings.json` 의 `autoCompactEnabled: false` 또는 env `DISABLE_AUTO_COMPACT=1`. 임계값은 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`(낮추는 방향만, 비공식)·`CLAUDE_CODE_AUTO_COMPACT_WINDOW`(비공식)로 추정 조정.
- **compact 후 재로드되는 것**: 프로젝트 루트 `CLAUDE.md`, auto memory(`MEMORY.md` 앞 200줄/25KB), 호출된 skill 본문. **손실되는 것**: `#` 인-대화 메모리(요약에 묻힘), path-scoped rules·중첩 CLAUDE.md(해당 파일을 다시 읽기 전까지).
- 출처: code.claude.com/docs `context-window`, `memory`, `settings`.

## 2. 진단 — 우려가 맞는가
두 개념을 분리해야 한다:
- **(A) compact 임계값** = 언제 요약할지(노브).
- **(B) in-window 일관성** = 모델이 윈도우 안 전체를 온전히 인지하는가(attention 한계, "lost in the middle").

사용자 직관은 절반 맞다: 200K에서 compact하면 디테일 손실, 1M까지 채우면 **(B) recall/일관성 저하**.
**핵심 반전**: 임계값을 600K~1M로 **올린다고 일관성이 좋아지지 않는다 — in-window가 커질수록 희석돼 오히려 나빠진다.** 즉 "끝까지 큰 컨텍스트를 유지"하는 것은 목표가 아니라 문제다.

## 3. ralph 기본 방식 — 이미 compaction 내성 구조
ralph는 거대 컨텍스트를 유지하지 않는다. 대신 **상태를 외부 파일에 박제**한다:
- `prd.json` — 스토리 + `passes`(작업 분해 + 완료 상태)
- `progress.txt` — 한 일·변경 파일·학습
매 이터레이션 이 파일들을 **재읽기**해 재정렬(re-ground)한다. 대화가 compact돼도 source-of-truth가 디스크에 있어 안전하다.
→ ralph = **린 컨텍스트 + 외부 영속 상태 + 재읽기**.

## 4. 두 접근 비교
| 항목 | 사용자안 (A) | ralph식/권장 (B) |
|------|--------------|------------------|
| 방식 | auto-compact 끄고, 400~600K에서 memory 1회 기록 → compact → 재읽기 | 마일스톤마다 외부 체크포인트 상시 기록 + compact는 자유(또는 `/compact focus`) |
| 체크포인트 빈도 | 임계 도달 시 1회(늦고 큼) | 작업 단위마다(잦고 작음) |
| 손실 위험 | 누적분을 한 번에 요약 → 디테일 유실 큼, 크래시 시 손실 큼 | 항상 최신 상태 박제 → 어느 시점 compact/크래시도 안전 |
| auto-compact 끄기 | 하드리밋 충돌·에러 위험 | 끌 필요 없음(외부 상태가 안전망) |
| 복잡도 | 임계 감시 로직 필요 | 단순(기록 습관 + 재읽기) |

→ 사용자안은 **외부화라는 핵심은 옳지만** 타이밍이 늦고 단발성이라 약하다. B가 더 견고하다.

## 5. 권장안 (하이브리드) + 구체 절차
1. **auto-compact 완전 비활성화는 비추천**(하드리밋 충돌 위험). 1M 윈도우는 **헤드룸/안전망**으로 두되 **채우는 목표로 삼지 않는다**.
2. **상시 외부 체크포인트(핵심)**: 작업을 스토리로 분해하고, 마일스톤마다 `CHECKPOINT.md`(또는 progress)에서 *한 일·다음 할 일·핵심 결정·파일 경로*를 갱신. 영속 위치는 **루트 CLAUDE.md / auto memory(MEMORY.md)** — compact 후 자동 재로드됨. (`#` 메모리·중첩 CLAUDE.md는 손실되니 의존 금지.)
3. **능동 압축**: 큰 컨텍스트가 쌓이기 전 마일스톤마다 **`/compact focus <보존할 핵심>`** 으로 직접 요약 범위 지정.
4. **재진입 규약**: compact/재시작 후 **가장 먼저 체크포인트(+prd.json) 재읽기** → 그 지점부터 이어감. (autonomous_workflow의 logs 재읽기와 동일 원리.)
5. **대용량 읽기는 subagent 위임**: 메인 컨텍스트엔 결론만 남긴다.
6. **임계값 튜닝(선택)**: 조정한다면 `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`로 **낮춰** 더 자주 compact하고 디테일을 외부 체크포인트로 흘려보내는 쪽. 600K로 **올리는** 것은 일관성 관점에서 역효과.

## 6. 하네스 반영(실행 시)
- `rules/context_management.md` 추가(위 규약) → 복제 대상에 포함.
- `rules/autonomous_workflow.md`에 "체크포인트 기록 + 재진입 재읽기" 단계 통합(이미 `logs/iterations.md` 존재 → CHECKPOINT 개념과 합침).
- `.env.example`에 `DISABLE_AUTO_COMPACT`/`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` 주석으로 안내(기본은 건드리지 않음).

## 결론
목표는 "끝까지 큰 컨텍스트 유지"가 아니라 **"린 컨텍스트 + 외부 영속 상태 + 잦은 능동 compact + 재읽기"** 다. 사용자안은 외부화라는 핵심을 잡았으나 단발·late 라서, **ralph식 상시 체크포인트로 일반화**하는 것이 더 낫다. auto-compact는 끄지 말고 안전망으로 두되, 실제 연속성은 체크포인트가 책임진다.
