# Changelog

## 0.1.2
* mDNS discovery now runs as a long-lived watcher (a one-shot scan rarely sees the phone's announcement); new `adb_endpoint` option; candidates are tried in order: option, watcher, last working endpoint.

## 0.1.1
* Drop the deprecated build.json: Supervisor ignored it and built on its Alpine base. The base image (node:26-slim) is now the Dockerfile's default.

## 0.1.0
* First release: tasker-mcp 0.1.7 served as streamable HTTP with a bearer token; adb Wireless debugging route with mDNS discovery
  (python3-zeroconf) and a tailnet fallback; route watchdog; write allow list and auto-persist as options.
