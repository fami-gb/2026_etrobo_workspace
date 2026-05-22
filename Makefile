.DEFAULT_GOAL := build

APP_IMG ?= kait-etrobocon2026
DOCKER_COMPOSE ?= docker compose
QUIET ?= 1
BUILD_LOG ?= build.log
IN_DOCKER := $(shell [ -f /.dockerenv ] && echo 1 || echo 0)
SPIKE_WORKSPACE_DIR := /opt/spike-rt/sdk/workspace

.PHONY: help build img clean realclean distclean upload

help:
	@echo "Usage:"
	@echo "  make build                asp.binを作る"
	@echo "  make clean                app/build配下の生成物を消す"
	@echo "  make realclean            appとカーネル関連の生成物を消す"
	@echo "  make distclean            ワークスペース全体の生成物を消す"
	@echo "  make upload               DFUモードでasp.binをハブにアップロードする"
	@echo ""
	@echo "Variables:"
	@echo "  APP_IMG=<folder>          sdk/workspace内のappマウントフォルダ名"
	@echo "  QUIET=1|0                 1で簡易表示（既定）、0で詳細ログ表示"
	@echo "  BUILD_LOG=<path>          QUIET=1時のログ出力先（既定: build.log）"
	@echo ""
	@echo "Examples:"
	@echo "  make build"
	@echo "  QUIET=0 make build"
	@echo "  APP_IMG=myapp make build"
	@echo "  docker compose run --rm builder make img=kait-etrobocon2026"

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

realclean:
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		$(MAKE) -C $(SPIKE_WORKSPACE_DIR) realclean; \
	else \
		APP_IMG=$(APP_IMG) $(DOCKER_COMPOSE) run --rm builder make realclean; \
	fi

distclean:
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		$(MAKE) -C $(SPIKE_WORKSPACE_DIR) distclean; \
	else \
		APP_IMG=$(APP_IMG) $(DOCKER_COMPOSE) run --rm builder make distclean; \
	fi

upload:
	@if [ "$(IN_DOCKER)" = "1" ]; then \
		$(MAKE) -C $(SPIKE_WORKSPACE_DIR) upload; \
	else \
		APP_IMG=$(APP_IMG) $(DOCKER_COMPOSE) run --rm builder make upload; \
	fi
