ARG BUILD_FROM=node:26-slim
FROM $BUILD_FROM

# adb talks to the phone's Wireless debugging; python3-zeroconf watches for its (changing) port; jq/curl/unzip are used below and by run.sh.
# Debian's adb (34) fails the Wireless debugging handshake with current Android, so on x86_64 we use Google's own platform-tools
# (no arm64 build exists upstream: there the Debian adb is the fallback).
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq curl ca-certificates python3 python3-zeroconf unzip \
 && if [ "$(uname -m)" = "x86_64" ]; then \
      curl -fsSL https://dl.google.com/android/repository/platform-tools-latest-linux.zip -o /tmp/pt.zip \
      && unzip -q /tmp/pt.zip -d /opt && ln -s /opt/platform-tools/adb /usr/local/bin/adb && rm /tmp/pt.zip; \
    else apt-get install -y --no-install-recommends adb; fi \
 && rm -rf /var/lib/apt/lists/*

ARG TASKER_MCP_VERSION=0.1.7
RUN npm install -g --omit=dev "@pmaxhogan/tasker-mcp@${TASKER_MCP_VERSION}" \
 && npm cache clean --force

COPY bridge.mjs run.sh discover.py /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
