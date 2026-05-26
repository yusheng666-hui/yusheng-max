.PHONY: setup setup-flutter setup-python format lint test test-flutter test-python build-apk clean

setup-flutter:
	cd src/flutter_app && flutter pub get && dart run build_runner build

setup-python:
	cd src/backend && pip install -r requirements.txt && pre-commit install

setup: setup-flutter setup-python

format:
	cd src/backend && black src/backend/app/ src/backend/tests/ && ruff check --fix src/backend/app/ src/backend/tests/
	cd src/flutter_app && dart format lib/ test/

lint:
	cd src/backend && ruff check src/backend/app/ src/backend/tests/ && mypy src/backend/app/
	cd src/flutter_app && dart analyze

test:
	cd src/flutter_app && flutter test
	cd src/backend && pytest

test-flutter:
	cd src/flutter_app && flutter test

test-python:
	cd src/backend && pytest

build-apk:
	cd src/flutter_app && flutter build apk --debug

clean:
	cd src/flutter_app && flutter clean
	find src/backend -type d -name __pycache__ -exec rm -rf {} +
