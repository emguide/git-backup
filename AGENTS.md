# git-auto-sync — Agent Guide

## Project Overview

`git-auto-sync` is a lightweight Linux daemon written in Python 3 that watches configured directories and automatically commits and pushes changes to git after a configurable period of inactivity. It **only commits and pushes** — it never pulls or merges.

The project is intentionally minimal: a single executable Python script, an example JSON config, and a systemd user service unit file.

## Files

| File | Purpose |
|------|---------|
| `git-auto-sync` | Main executable Python script (no `.py` extension). Contains all daemon logic. |
| `config.json` | Example configuration file. |
| `git-auto-sync.service` | systemd user service unit template. |
| `README.md` | Human-facing documentation with installation and usage instructions. |

## Technology Stack

- **Language**: Python 3.9+
- **Runtime dependency**: `python3-watchdog` (or `pip install watchdog`)
- **OS requirement**: Linux (relies on `inotify` via `watchdog`)
- **Service management**: systemd user services
- **No build system**: There is no `pyproject.toml`, `setup.py`, `Makefile`, or package manager configuration. The script is intended to be run directly.

## Architecture

The script is organized around two classes and a small CLI bootstrap:

### `GitBackup`
- One instance per watched directory.
- Manages a debounce `threading.Timer` protected by a `threading.Lock`.
- `on_change()` resets the timer whenever a file system event occurs.
- `_commit()` runs the sync sequence when the timer expires:
  1. `git add -A`
  2. `git diff --cached --quiet` (skip commit if nothing staged)
  3. `git commit -m "auto-sync: <timestamp>"`
  4. `git push` (optionally `git push origin <branch>` if configured)
- On startup, every `GitBackup` gets an immediate `on_change()` call to sync any changes that happened while the daemon was offline.

### `EventHandler`
- Extends `watchdog.events.FileSystemEventHandler`.
- Filters out events inside `.git/` (to prevent loops) and `"opened"` events.
- Delegates all other events to `GitBackup.on_change()`.

### `Observer` lifecycle
- One `watchdog.observers.Observer` per watched directory, scheduled recursively.
- On `SIGTERM` or `SIGINT`, all observers are stopped and joined for graceful shutdown.

## Configuration

The daemon expects a JSON config file. Default path: `~/.config/git-auto-sync/config.json`.

A top-level list is accepted as shorthand for `{"directories": [...]}`.

Full schema:

```json
{
  "directories": [
    "/home/user/projects/dotfiles",
    {
      "path": "/home/user/projects/notes",
      "delay_seconds": 600,
      "branch": "main"
    }
  ],
  "default_delay_seconds": 300
}
```

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `directories` | `string[] \| object[]` | — | Paths to watch. Each must already be a git repo with a remote configured. |
| `path` | `string` | — | Directory path (when using object form). |
| `delay_seconds` | `number` | `default_delay_seconds` | Inactivity timer in seconds. |
| `branch` | `string \| null` | `null` | If set, pushes explicitly to `origin <branch>`. |
| `default_delay_seconds` | `number` | `300` | Fallback delay for entries that don't specify one. |

## Running Locally

```bash
# Install the runtime dependency
pip install watchdog

# Run with the example config
./git-auto-sync -c config.json -v

# Run with default config path
./git-auto-sync -v
```

## Deployment

There is no automated deployment or CI pipeline. Installation is manual:

1. Copy `git-auto-sync` to `~/.local/bin/` and ensure it is executable.
2. Copy `config.json` to `~/.config/git-auto-sync/config.json` and edit paths.
3. Copy `git-auto-sync.service` to `~/.config/systemd/user/`.
4. Run `systemctl --user daemon-reload`, then `systemctl --user enable --now git-auto-sync`.

For persistence after logout:
```bash
loginctl enable-linger "$USER"
```

View logs:
```bash
journalctl --user -u git-auto-sync -f
```

## Code Style Guidelines

- **Type hints**: Used throughout (`path: Path`, `branch: str | None = None`).
- **Path handling**: Prefer `pathlib.Path` over string paths.
- **Logging**: Use the standard `logging` module. Loggers are namespaced per directory (`git-auto-sync.{dirname}`).
- **Subprocess calls**: Always use `subprocess.run(..., check=True, capture_output=True, text=True)` — never `shell=True`.
- **Thread safety**: Shared timer state is protected with `threading.Lock`.
- **No external formatting/linting config**: Follow PEP 8 and the existing visual style.

## Testing

There is currently no test suite. Because the script is a thin wrapper around `watchdog` and `subprocess`, meaningful unit tests would require mocking the file system and git commands.

If you add tests, a minimal `pytest` setup would be appropriate. The project has no packaging metadata, so tests would live in a `tests/` directory and be run with `pytest` directly.

## Security Considerations

- The daemon runs as the installing user (systemd *user* service). It should **not** be run as root.
- Git commands are invoked via `subprocess.run` with explicit argument lists (`shell=False`), which mitigates shell-injection risks.
- There is no validation of the git remote or repository contents beyond checking that `.git` exists.
- Because the script **never pulls**, it avoids the risks associated with automatically merging remote changes.
- Events inside `.git/` are explicitly ignored to prevent infinite loops caused by git's own file modifications.
