# 공통 개발 작업 진입점.  사용: make setup / make test / make lint / make format / make run
VENV ?= venv
PY := $(VENV)/bin/python

.PHONY: setup lint format test run clean

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

run:  ## src/main.py 실행(결과물 생성)
	$(PY) src/main.py

eval:  ## 결과물 vs golden 평가(spec.yaml). produce 와 동일한 venv 인터프리터 사용
	$(PY) tools/evaluate.py spec.yaml

clean:  ## venv·캐시 정리
	rm -rf $(VENV) .pytest_cache .ruff_cache
	find . -type d -name __pycache__ -prune -exec rm -rf {} +
