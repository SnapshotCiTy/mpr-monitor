#!/bin/sh

# mpr-monitor install/uninstall script for FreeBSD
# Usage:
#   ./install.sh              Install and start services
#   ./install.sh uninstall    Stop services and remove all files

set -e

APP_DIR="/usr/local/share/mpr_monitor"
DATA_DIR="/var/log/mpr_monitor"
RCD_DIR="/usr/local/etc/rc.d"
SRC_DIR="$(dirname "$0")/src"

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info()  { printf "${GREEN}>>>${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}>>>${NC} %s\n" "$1"; }
error() { printf "${RED}>>>${NC} %s\n" "$1"; }

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root."
        exit 1
    fi
}

check_python() {
    if [ ! -x /usr/local/bin/python3 ]; then
        error "Python 3 not found at /usr/local/bin/python3"
        error "Install with: pkg install python3"
        exit 1
    fi
}

check_mpr() {
    found=0
    for drv in mpr mps; do
        for i in 0 1 2 3 4 5; do
            if sysctl -n dev.${drv}.${i}.chain_free > /dev/null 2>&1; then
                found=1
                break 2
            fi
        done
    done
    if [ ${found} -eq 0 ]; then
        error "No mpr or mps controllers detected on this system."
        exit 1
    fi
}

check_src() {
    if [ ! -d "${SRC_DIR}" ]; then
        error "Source directory not found: ${SRC_DIR}"
        error "Run this script from the mpr-monitor repository root."
        exit 1
    fi
    for f in index.html mpr_monitor_httpd.py mpr_collect.sh rc.d/mpr_monitor rc.d/mpr_collect; do
        if [ ! -f "${SRC_DIR}/${f}" ]; then
            error "Missing source file: ${SRC_DIR}/${f}"
            exit 1
        fi
    done
}

do_install() {
    info "Installing mpr-monitor"

    check_root
    check_python
    check_mpr
    check_src

    # Stop existing services if running
    if service mpr_monitor status > /dev/null 2>&1; then
        warn "Stopping existing mpr_monitor service..."
        service mpr_monitor stop || true
    fi
    if service mpr_collect status > /dev/null 2>&1; then
        warn "Stopping existing mpr_collect service..."
        service mpr_collect stop || true
    fi

    # Create directories
    info "Creating directories"
    mkdir -p "${APP_DIR}"
    mkdir -p "${DATA_DIR}"
    chmod 755 "${DATA_DIR}"

    # Install application files
    info "Installing application files to ${APP_DIR}"
    install -m 644 "${SRC_DIR}/index.html"            "${APP_DIR}/index.html"
    install -m 644 "${SRC_DIR}/mpr_monitor_httpd.py"   "${APP_DIR}/mpr_monitor_httpd.py"
    install -m 755 "${SRC_DIR}/mpr_collect.sh"         "${APP_DIR}/mpr_collect.sh"

    # Install rc.d scripts
    info "Installing rc.d service scripts"
    install -m 755 "${SRC_DIR}/rc.d/mpr_monitor"  "${RCD_DIR}/mpr_monitor"
    install -m 755 "${SRC_DIR}/rc.d/mpr_collect"  "${RCD_DIR}/mpr_collect"

    # Enable services
    info "Enabling services in rc.conf"
    sysrc mpr_collect_enable=YES
    sysrc mpr_monitor_enable=YES

    # Start services
    info "Starting mpr_collect"
    service mpr_collect start

    info "Starting mpr_monitor"
    service mpr_monitor start

    # Verify
    echo ""
    service mpr_collect status
    service mpr_monitor status

    echo ""
    info "Installation complete."
    info "Dashboard: http://$(hostname):8080"
    info "Data directory: ${DATA_DIR}"
    echo ""
}

do_uninstall() {
    info "Uninstalling mpr-monitor"

    check_root

    # Stop services
    if [ -f "${RCD_DIR}/mpr_monitor" ]; then
        info "Stopping mpr_monitor"
        service mpr_monitor stop 2>/dev/null || true
    fi
    if [ -f "${RCD_DIR}/mpr_collect" ]; then
        info "Stopping mpr_collect"
        service mpr_collect stop 2>/dev/null || true
    fi

    # Remove rc.conf entries
    info "Removing rc.conf entries"
    sysrc -x mpr_monitor_enable 2>/dev/null || true
    sysrc -x mpr_collect_enable 2>/dev/null || true

    # Remove rc.d scripts
    info "Removing rc.d scripts"
    rm -f "${RCD_DIR}/mpr_monitor"
    rm -f "${RCD_DIR}/mpr_collect"

    # Remove application files
    info "Removing application files"
    rm -rf "${APP_DIR}"

    # Remove PID files
    rm -f /var/run/mpr_monitor.pid
    rm -f /var/run/mpr_collect.pid

    # Remove log files
    info "Removing log files"
    rm -f /var/log/mpr_monitor.log
    rm -f /var/log/mpr_collect.log

    # Ask about data
    echo ""
    warn "Data directory ${DATA_DIR} contains collected CSV files."
    printf "Remove collected data? [y/N] "
    read answer
    case "${answer}" in
        [yY]|[yY][eE][sS])
            info "Removing data directory"
            rm -rf "${DATA_DIR}"
            ;;
        *)
            info "Keeping data directory: ${DATA_DIR}"
            ;;
    esac

    echo ""
    info "Uninstallation complete. System is clean."
}

# Main
case "${1}" in
    uninstall)
        do_uninstall
        ;;
    *)
        do_install
        ;;
esac
