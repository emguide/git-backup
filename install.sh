#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/git-backup"
SYSTEMD_DIR="${HOME}/.config/systemd/user"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  install     Install git-backup binary, config, and systemd service
  uninstall   Stop and remove git-backup binary, config, and systemd service
  update      Reinstall the binary and restart the service
  start       Start the systemd user service
  stop        Stop the systemd user service
  status      Show systemd service status
EOF
}

install_binary() {
    echo "Installing git-backup to ${BIN_DIR}..."
    mkdir -p "${BIN_DIR}"
    cp "${SCRIPT_DIR}/git-backup" "${BIN_DIR}/git-backup"
    chmod +x "${BIN_DIR}/git-backup"
}

install_config() {
    if [[ -f "${CONFIG_DIR}/config.json" ]]; then
        echo "Config already exists at ${CONFIG_DIR}/config.json — skipping."
        echo "  (Remove it first if you want a fresh copy from example.config.json)"
    else
        echo "Installing example config to ${CONFIG_DIR}/config.json..."
        mkdir -p "${CONFIG_DIR}"
        cp "${SCRIPT_DIR}/example.config.json" "${CONFIG_DIR}/config.json"
        echo "  EDIT ${CONFIG_DIR}/config.json to add your directories."
    fi
}

install_service() {
    echo "Installing systemd user service..."
    mkdir -p "${SYSTEMD_DIR}"
    cp "${SCRIPT_DIR}/git-backup.service" "${SYSTEMD_DIR}/git-backup.service"
    systemctl --user daemon-reload
    systemctl --user enable git-backup
}

cmd_install() {
    install_binary
    install_config
    install_service
    echo
    echo "git-backup installed. Start it with: ./install.sh start"
    echo "  Binary:   ${BIN_DIR}/git-backup"
    echo "  Config:   ${CONFIG_DIR}/config.json"
    echo "  Service:  ${SYSTEMD_DIR}/git-backup.service"
    echo
    echo "View logs with: journalctl --user -u git-backup -f"
}

cmd_uninstall() {
    if systemctl --user is-active --quiet git-backup 2>/dev/null; then
        echo "Stopping git-backup service..."
        systemctl --user stop git-backup || true
    fi
    if systemctl --user is-enabled --quiet git-backup 2>/dev/null; then
        echo "Disabling git-backup service..."
        systemctl --user disable git-backup || true
    fi

    if [[ -f "${SYSTEMD_DIR}/git-backup.service" ]]; then
        echo "Removing systemd service file..."
        rm "${SYSTEMD_DIR}/git-backup.service"
        systemctl --user daemon-reload
    fi

    if [[ -f "${BIN_DIR}/git-backup" ]]; then
        echo "Removing binary..."
        rm "${BIN_DIR}/git-backup"
    fi

    echo "Uninstall complete."
    echo "  Config directory left in place: ${CONFIG_DIR}"
}

cmd_update() {
    install_binary
    if systemctl --user is-active --quiet git-backup 2>/dev/null; then
        echo "Restarting git-backup service..."
        systemctl --user restart git-backup
    else
        echo "Service not running. Starting..."
        systemctl --user start git-backup
    fi
    echo "Update complete."
}

cmd_start() {
    echo "Starting git-backup service..."
    systemctl --user start git-backup
}

cmd_stop() {
    echo "Stopping git-backup service..."
    systemctl --user stop git-backup || true
}

cmd_status() {
    systemctl --user status git-backup || true
}

case "${1:-}" in
    install)
        cmd_install
        ;;
    uninstall)
        cmd_uninstall
        ;;
    update)
        cmd_update
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    status)
        cmd_status
        ;;
    *)
        usage
        exit 1
        ;;
esac
