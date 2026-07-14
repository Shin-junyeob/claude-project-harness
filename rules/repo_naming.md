# GitHub 저장소 이름 규칙 (공통)

> 로컬 팀 폴더명은 한글을 써도 되지만, **GitHub 저장소 이름은 ASCII 만 허용**된다.
> 한글을 그대로 `gh repo create` 에 넘기면 GitHub 가 비ASCII 를 `-` 로 치환해 `"-"` 같은 이름이 만들어진다.

## 규칙
GitHub 저장소 이름은 다음 형식을 따른다:
```
<조직접두사>_<영문팀명>-automation
```
- 영문 소문자/숫자/`_`/`-`/`.` 만 사용
- 한글 팀명을 영문으로 옮긴다(단어 구분은 `-`)

## 한글 팀명 → 영문 매핑 (team_repo_map.sh)
한글 팀명을 어떤 영문 repo 이름으로 만들지는 **`team_repo_map.sh`** 에 정의한다.
- 이 파일은 **조직 고유 정보**라 **로컬 전용**이다 — public 저장소에 발행하지 않으며 새 프로젝트에도 복제하지 않는다.
- `new-project.sh` 가 `bash team_repo_map.sh "<팀명>"` 으로 호출해 repo 이름을 얻는다.
- 새 팀은 `team_repo_map.sh` 의 `case` 에 한 줄 추가한다.

각 조직은 하네스 루트에 자신의 `team_repo_map.sh` 를 둔다. 예시 형식:
```bash
case "$1" in
  *<한글팀명>*) echo "<조직접두사>_<영문팀명>-automation" ;;
  *)            echo "" ;;
esac
```

## 생성 방법 (new-project.sh)
- **매핑된 팀**: `./new-project.sh <한글폴더명>` → `team_repo_map.sh` 가 정한 이름으로 GitHub repo 생성.
- **매핑에 없는 팀**: 영문 repo 명을 2번째 인자로 직접 지정한다.
  ```bash
  ./new-project.sh <한글폴더명> <조직접두사>_<영문팀명>-automation
  ```
- 매핑도 없고 인자도 없는데 폴더명이 **비ASCII** 면 **GitHub 연동만 건너뛴다**(로컬 팀 폴더는 정상 생성). `"-"` 같은 잘못된 repo 가 만들어지지 않는다.
- 폴더명이 이미 유효한 ASCII 면 그 이름을 그대로 repo 명으로 쓴다.
