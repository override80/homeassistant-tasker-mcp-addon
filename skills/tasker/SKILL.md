---
name: tasker
description: Read, edit, test and debug Tasker (Android automation) on a real phone through the Tasker MCP server (tools such as get_task, edit_task, run_actions, persist_config). Use when the user wants to change Tasker tasks, profiles or projects, test actions safely, read Tasker's run log or preferences, restructure a setup, or fix a "Tasker Action Error".
license: MIT
---

# Working with Tasker through the Tasker MCP

Needs the [Tasker MCP](https://github.com/pmaxhogan/tasker-mcp) (or this Home Assistant add-on) connected. Start with `ping`, then
`list_projects` / `list_profiles` / `list_tasks`. MIT licensed, like the rest of this repository.

## Ground rules

1. **Read before you write.** `get_task` / `get_profile`, then change. Every mutation saves a snapshot first: mention its id so
   the user can undo it with `restore_snapshot`.
2. **Changes are live only until saved.** `persist_config` writes them to disk, but it drives Tasker's editor over adb and needs
   the phone **unlocked and awake**. It never unlocks the phone: ask the user to. A Tasker restart loses unsaved changes.
3. **Respect the write limit.** The server may only allow some name prefixes (`write_allow`; empty means no limit and also allows
   whole-configuration imports: rename, delete, profile edits, `move_to_project`, `restore_snapshot`). If a write is refused, do
   not dodge it by renaming or moving things. Tell the user how to widen the list, and let them decide.
4. **Test without side effects.** Use `run_actions` (a scratch task) to try conditions and logic, and `Return` a string.
   Do not run real tasks that change DND, volume, VPN, doors, gates or alarms just to see what happens.
5. **Prefer disabling to deleting** (`set_profile_enabled`, or `enabled: false` on an action). Move retired items to an "Old"
   project once the new setup has run for a few days.

## Gotchas learned on a real phone

- **`run_actions` answers `ok: true` even when an action fails.** A failing action silently stops the scratch task, so a later
  `Return` comes back empty. Check real state in a separate call, and use long variable names.
- **Set Tasker Pref validates the *stored* preferences before applying anything.** Pref 6 is the Display-Off check time and
  pref 7 the Display-Off check timeout (Tasker 6.7). Rules from Tasker's own messages: Wi-Fi and Bluetooth minimum timeout
  <= off-timeout - 15, and off-timeout <= off-time - 5. A step that leaves the stored values invalid (for example timeout = 10
  with a 15 s Wi-Fi minimum) is accepted once, and then every later Set Tasker Pref fails with "off check timeout must be at
  least 15s > wifi timeout" until someone fixes the value in Preferences > Monitor. Never set the timeout below
  wifi/bt minimum + 15. Read prefs (read-only) with a Java Code action:
  `context.getSharedPreferences("net.dinglisch.android.tasker.preffy", 0).getAll()`. Keys are abbreviated (`lfdd`, `sows`, `wip`,
  `bttp`, `wfpiod`, `btpiod`). Do not write prefs directly.
- **Perform Task:** `Parameter 1` is arg 2 (`%par1`), `Parameter 2` is arg 3. A profile cannot pass parameters, so give each
  profile a thin entry task that calls the shared task with a parameter.
- **Collision handling:** 0 abort new, 1 abort existing, 2 run both. Use 2 for tasks that `Wait`, so a second event is not lost.
- **Android has no `curl`.** `Run Shell` with `curl` silently does nothing. Use the `HTTP Request` action (method 0 = GET,
  arg 2 URL, arg 3 headers, arg 4 query, arg 5 body, arg 8 timeout). Webhooks (Home Assistant and similar) work well with GET.
- **Condition ops** (verified): 0 eq, 1 neq, 2 matches, 3 not matches, 4 matches regex, 5 not matches regex, 6 lt, 7 gt, 12 set,
  13 not set.
- **Current SSID:** `Test Net` type 5 stores it in a variable (`<unknown ssid>` when not connected).
- **Run log:** the MCP cannot export it (HTTP 501). Read `/sdcard/Tasker/log/runlog.txt` over adb. Lines are `T Running / ExitOK /
  ExitErr / ExitRep / RejCopy` (RejCopy = a new copy was rejected by collision handling, ExitRep = replaced), `P Active / Inactive`
  for profiles, and `A OK / IfFail / Fail` per action. It only keeps a few hours.

## Editing a full backup file instead of the live config

Sometimes a bulk change is easier on an exported backup, then restored (a restore replaces everything: take a backup first).

- `<Project sr="projN">` indexes must be contiguous from 0, or Tasker silently drops every project after the first gap.
- Escape `&` as `&amp;` in text (URLs with query strings). Keep each task's `<Action sr="actN">` numbers contiguous.
- A named task must be listed in some project's `tids`, or it falls back into Base. A profile belongs to exactly one project.
- Do not write an action's argument layout from memory. Build the action once in the Tasker GUI, export it, and copy the XML.

## Workflows

- **Fix an error popup:** `get_task` -> find the action -> `search_docs` / `get_doc` -> try it with `run_actions` -> `edit_task`
  -> read it back -> `persist_config` (phone unlocked).
- **Refactor profiles:** build the new tasks, test the logic with `run_actions`, create the new profile, disable the old ones,
  watch the run log for a few days, then move the old ones to "Old".
- **Share a setup:** exports contain tokens, URLs and IPs in plain text. Replace them with variables before sharing anything.
