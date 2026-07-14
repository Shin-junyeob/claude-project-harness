# 팀 공용 개발 toolchain 진입점.  사용: make setup / make test / make lint / make format / make clean
#   결과물 생성/평가(run/eval)와 /autoloop 은 각 자동화 폴더(subproject 복제본) 안에서 실행한다:
#     cd <자동화명> && make run / make eval     (그 폴더 Makefile 이 ../venv·../tools 를 공유)
VENV ?= venv
PY := $(VENV)/bin/python

.PHONY: setup lint format test clean

setup:  ## venv 생성 + dev 의존성 설치
	python3 -m venv $(VENV)
	$(PY) -m pip install --upgrade pip
	$(PY) -m pip install -e ".[dev]"

lint:  ## ruff 린트
	$(VENV)/bin/ruff check .

format:  ## ruff 포맷
	$(VENV)/bin/ruff format .

test:  ## pytest 실행
	$(VENV)/bin/pytest

clean:  ## venv·캐시 정리
	rm -rf $(VENV) .pytest_cache .ruff_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
