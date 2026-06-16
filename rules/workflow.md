# 워크플로 (공통)

## 개발 흐름
1. **계획(planner)** — 요구사항 분석, 작업 계획 수립
2. **구현(implementer)** — 계획 기반 코드 작성 (`src/`)
3. **검증(validator)** — 요구사항 충족 여부 검증
4. **빌드/문서화(doc-updater)** — 빌드 성공 후 문서 갱신

## 브랜치 전략 (main / stable)
이 프로젝트는 **두 개의 브랜치**로 운영한다.

- **main** — 모든 수정·개발 작업을 진행하는 기본 브랜치.
- **stable** — 안정화·검증이 끝난 버전만 반영하는 브랜치.

### 규칙
- 일상적인 수정은 항상 `main`에서 진행한다.
- 충분히 안정된 버전만 `main` → `stable`로 **merge**한다.
- **`stable` 브랜치로의 merge는 `main` 의 CI(GitHub Actions)가 success 일 때만 허용된다.**
  - CI가 통과하지 않았거나 확인할 수 없으면 hook(`block_stable_merge`)이 차단한다(fallback).
  - (→ `.claude/hooks/block_stable_merge.sh`)

### 안전 장치(훅) 요약
- `block_dangerous_commands` — `rm -rf /`·`~`·`*`, `git push --force`, `git reset --hard`, `git clean -f`, `dd`/`mkfs` 등 되돌리기 어려운 명령 차단.
- `block_repo_delete` — 원격 저장소/브랜치 삭제 차단(명시 승인 시에만).
- `block_access` — 민감 경로(`.env`, `secrets/` 등) 수정 차단.
- `enforce_src_layout` — 구현 코드(`.py`/`.js`/`.cs` 등)는 `src/` 안에만 작성하도록 강제(`.claude/`·`tests/`·`.sh` 예외).
- `check_commit_message` — 커밋 메시지를 `type: subject`(영어) 형식으로 강제(→ [commit_conventions.md](commit_conventions.md)).

### 일반 절차
```bash
# 작업
git checkout main
# ... 수정 ...
git add -A && git commit -m "..."

# 안정 버전 반영 (사용자 명시 승인 후에만)
# 한 줄로 실행한다 — CI 게이트(block_stable_merge)가 이 형태를 감지한다.
git checkout stable && git merge main
git checkout main
```
> 주의: `git checkout stable` 와 `git merge main` 을 **별도 명령**으로 나눠 실행해도
> 훅이 현재 브랜치를 확인해 차단하지만, 위처럼 한 줄로 실행하는 것을 권장한다.
