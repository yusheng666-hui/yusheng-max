.PHONY: setup setup-flutter setup-python format lint test test-flutter test-python build-apk clean

setup-flutter:
	cd src/flutter_app && flutter pub get && dart run build_runner build

setup-python:
	cd src/backend && pip install -r requirements.txt && pre-commit install

setup: setup-flutter setup-python

format:
	cd src/backend && black app/ tests/ && ruff check --fix app/ tests/
	cd src/flutter_app && dart format lib/ test/

lint:
	cd src/backend && ruff check app/ tests/ && mypy app/
	cd src/flutter_app && dart analyze

test:
	cd src/flutter_app && flutter test
	cd src/backend && pytest

test-flutter:
	cd src/flutter_app && flutter test

test-python:
	cd src/backend && pytest

build-apk:
	cd src/flutter_app && flutter create --platforms=android . && \
	sed -i '/compileSdk/s/flutter\.compileSdkVersion/35/' android/app/build.gradle && \
	sed -i '/minSdk/s/flutter\.minSdkVersion/26/' android/app/build.gradle && \
	sed -i '/targetSdk/s/flutter\.targetSdkVersion/35/' android/app/build.gradle && \
	sed -i 's|id "com.android.application" version "[^"]*"|id "com.android.application" version "8.1.0"|' android/settings.gradle && \
	sed -i 's|id "org.jetbrains.kotlin.android" version "[^"]*"|id "org.jetbrains.kotlin.android" version "1.9.10"|' android/settings.gradle && \
	sed -i 's|gradle-[0-9.]*-all.zip|gradle-8.3-all.zip|' android/gradle/wrapper/gradle-wrapper.properties && \
	flutter build apk --debug

clean:
	cd src/flutter_app && flutter clean
	find src/backend -type d -name __pycache__ -exec rm -rf {} +
