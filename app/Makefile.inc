mkfile_path := $(dir $(lastword $(MAKEFILE_LIST)))
SRCLANG = c++

# app配下(直下)の全cppを自動でオブジェクト化する。
APP_CPP_SRCS := $(notdir $(wildcard $(mkfile_path)*.cpp))
APPL_CXXOBJS := $(APP_CPP_SRCS:.cpp=.o)

# C++のコンパイルオプション
APPL_CXXFLAGS += -std=gnu++17 -O2

# 自作ヘッダのパス
INCLUDES += -I$(mkfile_path)
