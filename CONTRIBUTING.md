# Contributing

Issues and pull requests are welcome. This project is MIT licensed and community owned: by contributing you agree that your
contribution is released under the same licence (see [LICENSE](LICENSE)).

* Keep the add-on small: it only wraps [`tasker-mcp`](https://github.com/pmaxhogan/tasker-mcp) for Home Assistant. Changes to the
  tools themselves belong upstream.
* Never commit tokens, IP addresses, pairing codes or exports from your own Tasker (they contain secrets in plain text).
* For the skill, only add things you verified on a real phone, and say which Tasker version.
* Run `bash -n run.sh` and `python3 -m py_compile discover.py` before opening a pull request.
