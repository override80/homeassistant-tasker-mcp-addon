# Third-party notices

This repository contains only the add-on wrapper (`run.sh`, `bridge.mjs`, `discover.py`, `Dockerfile`, `config.json`,
the skill and the documentation), which is MIT licensed (see `LICENSE`). It does **not** contain or redistribute any of the
software below. The container image installs it at build time from its official distributors, each under its own licence.

| component | how it gets in | licence |
|---|---|---|
| [`@pmaxhogan/tasker-mcp`](https://github.com/pmaxhogan/tasker-mcp) (the MCP server, by Max Hogan) | `npm install` in the Dockerfile | MIT (full text below) |
| [`@modelcontextprotocol/sdk`](https://github.com/modelcontextprotocol/typescript-sdk) | dependency of tasker-mcp | MIT |
| Node.js (base image `node:26-slim`) | Docker base image | MIT (and the licences of its bundled dependencies) |
| Android SDK Platform-Tools (`adb`, x86_64 builds) | downloaded from Google at image build time | Google's [Android SDK terms](https://developer.android.com/studio/terms) |
| Debian `adb` (arm64 builds only) | Debian package | Apache-2.0 and others (see the package copyright file) |
| [`python3-zeroconf`](https://github.com/python-zeroconf/python-zeroconf) | Debian package, imported (not copied) by `discover.py` | LGPL-2.1-or-later |
| `jq`, `curl`, `unzip`, `python3` | Debian packages | MIT, curl licence, Info-ZIP licence, PSF licence |

Tasker is a product of João Dias (joaoapps), Home Assistant is a project of the Open Home Foundation, and Android is a
trademark of Google LLC. This add-on is an independent community project and is not affiliated with or endorsed by any of them.

## tasker-mcp (MIT)

    MIT License
    
    Copyright (c) 2026 Max Hogan
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
