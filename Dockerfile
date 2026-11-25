ARG BUILD_FROM=node:26-slim
FROM $BUILD_FROM

# adb talks to the phone's Wireless debugging; python3-zeroconf finds its (changing) port; jq/curl are used by run.sh.
RUN apt-get update \
 && apt-get install -y --no-install-recommends adb jq curl ca-certificates python3 python3-zeroconf \
 && rm -rf /var/lib/apt/lists/*

ARG TASKER_MCP_VERSION=0.1.7
RUN npm install -g --omit=dev "@pmaxhogan/tasker-mcp@${TASKER_MCP_VERSION}" \
 && npm cache clean --force

COPY bridge.mjs run.sh discover.py /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
