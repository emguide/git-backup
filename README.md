# git-backup

A lightweight Linux daemon that watches directories and automatically commits and pushes changes to git after a configurable period of inactivity.

- **Commit and push only** — never pulls or merges
- **Debounce timer** — waits for inactivity before syncing so you don't get a commit on every file save
- **Systemd user service** — auto-starts on boot and can persist after logout
- **Simple JSON config**

## Prerequisites

- Linux (uses `inotify` via `watchdog`)
- Python 3.9+
- `python3-watchdog`

Install watchdog:

```bash
sudo apt install python3-watchdog
# or
pip3 install watchdog
```

## Installation

1. Clone the repo:

```bash
git clone https://github.com/emguide/git-backup.git
cd git-backup
```

2. Run the install script:

```bash
./install.sh install
```

This copies `git-backup` to `~/.local/bin/`, installs the example config (if missing), and enables the systemd user service.

3. Edit the config to add your directories:

```bash
# ~/.config/git-backup/config.json
```

> **Manual install**: If you prefer, you can copy the files by hand — see the earlier steps in the git history or the `install.sh` script itself.

### Other install script commands

```bash
./install.sh start     # Start the systemd service
./install.sh stop      # Stop the systemd service
./install.sh update    # Reinstall binary and restart service
./install.sh status    # Check service status
./install.sh uninstall # Stop and remove binary/service
```

### Persistence After Logout

By default, systemd user services stop when you log out. To keep the daemon running:

```bash
sudo loginctl enable-linger "$USER"
```

## Configuration

Config file location: `~/.config/git-backup/config.json`

### Simple list (uses default delay)

```json
{
  "directories": [
    "/home/alice/projects/dotfiles",
    "/home/alice/projects/notes"
  ],
  "default_delay_seconds": 300
}
```

### Per-directory options

```json
{
  "directories": [
    {
      "path": "/home/alice/projects/dotfiles",
      "delay_seconds": 60
    },
    {
      "path": "/home/alice/projects/notes",
      "delay_seconds": 600,
      "branch": "main",
      "exclude": ["node_modules", ".cache", "*.log"]
    }
  ],
  "default_delay_seconds": 300
}
```

| Option | Description |
|--------|-------------|
| `path` | Directory to watch (must already be a git repo with a remote configured) |
| `delay_seconds` | Seconds of inactivity after the last change before committing (default: `300`) |
| `branch` | Optional branch to push explicitly. If omitted, `git push` uses repo defaults |
| `exclude` | List of glob patterns for subpaths to ignore (e.g. `["node_modules", "*.log"]`) |
| `default_delay_seconds` | Default delay for entries that don't specify one |

## Running Manually

```bash
# With default config
git-backup

# With custom config
git-backup -c /path/to/config.json

# Verbose logging
git-backup -v
```

## How It Works

1. The daemon watches each configured directory recursively using `inotify`
2. Any file change resets that directory's debounce timer
3. When the timer expires (no changes for `delay_seconds`), the daemon:
   - Stages all changes with `git add -A`
   - Commits with a timestamp message if there are changes
   - Pushes to the configured remote
4. Events inside `.git/` are ignored so git operations don't loop
5. Events matching `exclude` patterns are also ignored

## Viewing Logs

```bash
# Follow logs
journalctl --user -u git-backup -f

# Since boot
journalctl --user -u git-backup -b
```

## Updating

Pull the latest changes and run the update command:

```bash
git pull
./install.sh update
```
