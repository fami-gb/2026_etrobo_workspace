mkfile_path := $(dir $(lastword $(MAKEFILE_LIST)))
SRCLANG = c++

# プロジェクト配下(再帰)の全cppを自動でオブジェクト化する。
APP_CPP_PATHS := $(shell find $(mkfile_path) -name '*.cpp' -print)
APP_CPP_SRCS := $(notdir $(APP_CPP_PATHS))
APPL_CXXOBJS := $(APP_CPP_SRCS:.cpp=.o)
APPL_DIRS += $(sort $(dir $(APP_CPP_PATHS)))

# C++のコンパイルオプション
APPL_CXXFLAGS += -std=gnu++17 -O2

# 自作ヘッダのパス
INCLUDES += \
    -I$(mkfile_path)include \
    -I$(mkfile_path)src \
    -I$(mkfile_path)external/drivers \

SPIKE_RT_DIR ?= /opt/spike-rt
INCLUDES += -I$(SPIKE_RT_DIR)/drivers/include
INCLUDES += -I$(SPIKE_RT_DIR)/external/libpybricks/lib/pbio/include
