# Tasker MCP — Home Assistant add-on

Runs [`tasker-mcp`](https://github.com/pmaxhogan/tasker-mcp) (an MCP server that lets an AI agent read, edit and run
[Tasker](https://tasker.joaoapps.com/) on an Android phone) as a proper Home Assistant add-on. The upstream server only speaks
stdio, so it normally runs as a throw-away `docker run` started by your MCP client; Home Assistant Supervisor then flags that
container as *"Unsupported software"*. As an add-on it is a known image, starts with the host, and is reachable as a normal
**streamable HTTP** MCP endpoint.

* Reaches the phone over **adb Wireless debugging** (finds its changing port by mDNS) and falls back to a **tailnet** address.
* Serves MCP on `http://127.0.0.1:8765/mcp` (loopback only by default) and requires `Authorization: Bearer <access_token>`.
* Keeps tasker-mcp's own safety nets: the **write allow list** (name prefixes the tools may change) and automatic **snapshots**.
* `GET /health` answers `ok` without a token (for a watchdog).

## Install

1. *Settings → Add-ons → Add-on store → ⋮ → Repositories*, add `https://github.com/override80/homeassistant-tasker-mcp-addon`.
2. Install **Tasker MCP**. Do not start it yet.
3. On the phone, set up the Tasker side as described in the tasker-mcp README (Tasker's HTTP server task and its bearer token).
4. Fill in the options (below) and start the add-on.

### Options

| option | meaning |
|---|---|
| `access_token` | **Required**, 16+ characters. Clients send it as `Authorization: Bearer …`. Make one with `openssl rand -hex 24`. |
| `tasker_token` | **Required.** The bearer token of the HTTP server in Tasker on the phone. |
| `phone_ip` | The phone's LAN address, to pick it out of the mDNS announcements. |
| `adb_endpoint` | Optional fixed Wireless debugging `ip:port` to try first (the port changes every time Wireless debugging is toggled; the add-on also watches mDNS and remembers the last endpoint that worked). |
| `tailnet_ip` | Optional fallback: the phone's Tailscale address (only works while the phone allows remote sessions). |
| `port`, `listen` | Where the MCP endpoint listens (default `127.0.0.1:8765`). Keep it on loopback unless you know why not. |
| `write_allow` | Comma separated name prefixes the mutating tools may touch (default `TaskerMCP.`). Add the names of tasks you want it to edit. **Empty means no limit** (and then whole-configuration imports are allowed too: rename, delete, profile edits, restore). Only do that for a client you trust; every change still saves a snapshot first. |
| `auto_persist` | Save Tasker's configuration after every change (drives Tasker's editor over adb; the phone must be awake). |
| `pair_endpoint`, `pair_code` | One-time adb pairing (see below); clear them afterwards. |

### adb pairing

Wireless debugging needs the add-on's adb key to be trusted by the phone once. Either:

* On the phone: *Developer options → Wireless debugging → Pair device with pairing code*, then put the `ip:port` and the code into
  `pair_endpoint` / `pair_code` and (re)start the add-on; clear both options afterwards. Or
* copy an already trusted `adbkey`, `adbkey.pub` and `adb_known_hosts.pb` into the add-on's data directory under `home/.android/`.

### Use it from Claude Code

```
claude mcp add --transport http tasker http://127.0.0.1:8765/mcp --header "Authorization: Bearer <access_token>"
```

## How it works

`run.sh` finds the phone (mDNS → `adb connect` → `adb forward`, or the tailnet address), then starts `bridge.mjs`, which loads the
`@pmaxhogan/tasker-mcp` package's own server and tool code and serves it with the MCP SDK's streamable HTTP transport (stateful
sessions, bearer token, loopback). A watchdog re-establishes the route when the phone leaves the network.

## Security notes

The endpoint can change Tasker on your phone, so treat `access_token` like a password. It listens on loopback only, so something
on the Home Assistant host (or a client that can reach that port) is needed to use it. The allow list limits what can be modified;
widen it deliberately.

## Skill for AI agents

[`skills/tasker/SKILL.md`](skills/tasker/SKILL.md) is a Claude Code skill (it also works as plain instructions for other agents) that
teaches an agent how to use this server safely: ground rules, the quirks found on a real phone and how to debug Tasker.
Copy the `skills/tasker` folder to `~/.claude/skills/` or to your project's `.claude/skills/`.

## License and community

This project is **free for everyone** and always will be: MIT licensed, no paid tiers, no accounts, no telemetry. Use it, fork it,
change it, redistribute it, even commercially, as long as the licence notice stays. It is maintained by the community; issues and
pull requests are welcome (see [CONTRIBUTING.md](CONTRIBUTING.md)).

* This add-on, its skill and its documentation: MIT, see [LICENSE](LICENSE).
* [`tasker-mcp`](https://github.com/pmaxhogan/tasker-mcp) by Max Hogan, the server this wraps, is also MIT.
* Every other component of the image, with its licence: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Not affiliated with Tasker (joaoapps), Home Assistant or Google.
