FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

ARG SPIKE_RT_REPO=https://github.com/shimojima/spike-rt.git
ARG SPIKE_RT_REF=etrobo

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    gcc-arm-none-eabi \
    libnewlib-arm-none-eabi \
    libstdc++-arm-none-eabi-newlib \
    python3 \
    python3-usb \
    libusb-1.0-0 \
    ruby \
    make \
    && rm -rf /var/lib/apt/lists/*

# asp.binの生成やアップロードに必要なものがあるsdk
RUN git clone --depth 1 --branch ${SPIKE_RT_REF} ${SPIKE_RT_REPO} /opt/spike-rt

WORKDIR /opt/spike-rt/sdk/workspace

CMD ["bash"]
