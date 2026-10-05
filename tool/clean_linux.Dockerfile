FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgtk-3-0 libstdc++6 libblkid1 liblzma5 libegl1 libgles2 libgl1-mesa-dri ca-certificates \
    xvfb xauth x11-utils dbus-x11 \
    && rm -rf /var/lib/apt/lists/*
ENV HOME=/tmp/home XDG_DATA_HOME=/tmp/home/.local/share
ENV LIBGL_ALWAYS_SOFTWARE=1 DENO_NO_UPDATE_CHECK=1
ENV NO_AT_BRIDGE=1
RUN mkdir -p /tmp/home
