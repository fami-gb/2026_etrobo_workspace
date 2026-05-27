.DEFAULT_GOAL := build

APP_IMG ?= kait-etrobocon2026
DOCKER_COMPOSE ?= docker compose
QUIET ?= 1
BUILD_LOG ?= build.log
IN_DOCKER := $(shell [ -f /.dockerenv ] && echo 1 || echo 0)
SPIKE_WORKSPACE_DIR := /opt/spike-rt/sdk/workspace
UPLOAD_SERVICE ?= uploader
UPLOAD_DO_BUILD ?= 1

.PHONY: help build img clean upload upload-nobuild _upload_impl

help:
	@echo "コマンド一覧:"
	@echo "  make build                asp.binを作る"
	@echo "  make clean                build配下の生成物を消す"
	@echo "  make upload               USB attach後にbuild+DFUアップロードする"
	@echo "  make upload-nobuild       既存asp.binを使ってDFUアップロードする"
	@echo ""
	@echo "変数:"
	@echo "  QUIET=1|0                 1で簡易表示（既定）、0で詳細ログ表示"
	@echo "  BUILD_LOG=<path>          QUIET=1時のログ出力先（既定: build.log）"
	@echo ""
	@echo "使い方:"
	@echo "  ビルドする				: make build"
	@echo "  ビルドログの詳細を表示する		: QUIET=0 make build"
	@echo "  SPIKEにbuild+uploadする		: make upload"
	@echo "  既存asp.binをuploadする		: make upload-nobuild"

build:
	@echo "building..."
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		if [ "$(QUIET)" = "1" ]; then \
			$(MAKE) -C $(SPIKE_WORKSPACE_DIR) img=$(APP_IMG) > "$(BUILD_LOG)" 2>&1 || { \
				status=$$?; \
				echo "build failed. last logs: $(BUILD_LOG)"; \
				tail -n 80 "$(BUILD_LOG)"; \
				exit $$status; \
			}; \
		else \
			$(MAKE) -C $(SPIKE_WORKSPACE_DIR) img=$(APP_IMG); \
		fi; \
	else \
		APP_IMG=$(APP_IMG) QUIET=$(QUIET) BUILD_LOG=$(BUILD_LOG) $(DOCKER_COMPOSE) run --rm builder make build; \
	fi
	@echo "Generated in container: /opt/spike-rt/sdk/workspace/asp.bin"

img:
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		$(MAKE) -C $(SPIKE_WORKSPACE_DIR) img=$(APP_IMG); \
	else \
		APP_IMG=$(APP_IMG) $(DOCKER_COMPOSE) run --rm builder make img=$(APP_IMG); \
	fi

clean:
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		$(MAKE) -C $(SPIKE_WORKSPACE_DIR) clean; \
	else \
		APP_IMG=$(APP_IMG) $(DOCKER_COMPOSE) run --rm builder make clean; \
	fi

upload:
	@$(MAKE) _upload_impl UPLOAD_DO_BUILD=1

upload-nobuild:
	@$(MAKE) _upload_impl UPLOAD_DO_BUILD=0

_upload_impl:
	@echo "Uploading to SPIKE..."
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		if [ ! -d /dev/bus/usb ]; then \
			echo "USBバスが見つかりません。uploader serviceで実行してください。"; \
			exit 2; \
		fi; \
		usb_nodes=$$(find /dev/bus/usb -mindepth 2 -maxdepth 2 -type c | wc -l); \
		if [ "$$usb_nodes" -eq 0 ]; then \
			echo "USBデバイスノードが見つかりません。コンテナ内から attach はできないため、ホスト側で先に usb-setup.sh を実行してください。" >&2; \
			ls -la /dev/bus/usb >&2 || true; \
			exit 2; \
		fi; \
		echo "USB preflight: $$usb_nodes node(s) detected under /dev/bus/usb"; \
		if [ "$(UPLOAD_DO_BUILD)" = "1" ]; then \
			echo "先にビルドを行います"; \
			$(MAKE) --no-print-directory build || { \
				status=$$?; \
				echo "ERROR: buildに失敗したためuploadを中止しました。" >&2; \
				exit $$status; \
			}; \
		else \
			if [ ! -f "$(SPIKE_WORKSPACE_DIR)/asp.bin" ]; then \
				echo "ERROR: $(SPIKE_WORKSPACE_DIR)/asp.bin が見つかりません。先に make build を実行してください。" >&2; \
				exit 4; \
			fi; \
		fi; \
		upload_log=$$(mktemp); \
		$(MAKE) -C $(SPIKE_WORKSPACE_DIR) upload > $$upload_log 2>&1; \
		upload_status=$$?; \
		if grep -qi "No DFU device found" $$upload_log; then \
			echo "ERROR: DFUデバイスが見つかりません。ハブをDFUモードにして再実行してください。" >&2; \
			rm -f $$upload_log; \
			exit 3; \
		fi; \
		if [ $$upload_status -ne 0 ]; then \
			echo "ERROR: spike-rt upload に失敗しました。" >&2; \
			tail -n 80 $$upload_log >&2 || true; \
			rm -f $$upload_log; \
			exit $$upload_status; \
		else \
			echo "実機へのアップロードに成功しました。"; \
		fi; \
		rm -f $$upload_log; \
	fi
