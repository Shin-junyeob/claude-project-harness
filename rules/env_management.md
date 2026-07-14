# 환경변수(.env) 관리 규칙 (공통)

## 계약
- **`.env.example`** = 필요한 환경변수의 **키 목록**(값 없음). 커밋되며 자유롭게 읽을 수 있다.
- **`.env`** = 실제 값. **커밋 금지**(`.gitignore`) + **직접 열람 금지**.

## 실행 전제 (핵심)
- `.env.example` 에 있는 키가 `.env` 에 **채워져 있다고 가정**하고 구현·실행한다.
- 값을 확인하려고 `.env` 를 열지 않는다. 코드가 **런타임에 python-dotenv 로 로드**한다:
  ```python
  from dotenv import load_dotenv
  load_dotenv()               # .env 를 읽어 os.environ 에 주입
  import os
  api_key = os.environ["API_KEY"]   # 키 이름은 .env.example 로 확인
  ```
- 필요한 키가 무엇인지는 항상 **`.env.example`** 을 기준으로 판단한다.

## 금지 (block_env_read 훅이 강제)
- `.env`(및 `.env.local`, `.env.production` 등 실제 env)를 `cat`/`grep`/`head` 나 Read 도구로 **직접 확인 금지** → 차단(exit 2).
- **허용**: `.env.example`(값 없는 템플릿) 읽기, `cp .env.example .env`(값 채우기용 복사), `source .env`(실행 시 로드).

## 셋업
- `make setup` 이 `python-dotenv` 를 설치한다(`pyproject.toml` 의 dependencies).
- 새 환경변수가 필요하면 **`.env.example` 에 키만**(값 없이) 추가하고, 실제 값은 각자 `.env` 에 채운다.
