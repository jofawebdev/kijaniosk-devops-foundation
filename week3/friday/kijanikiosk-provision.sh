#!/usr/bin/env bash
#
# KijaniKiosk Production Server Foundation
# Week 3 - Friday Independent Project
#
# Purpose:
#   Provision and verify a production-style Linux foundation for KijaniKiosk.
#
# Design goals:
#   - Idempotent execution.
#   - Explicit dirty-state detection and reconciliation.
#   - Least-privilege service accounts.
#   - Production-oriented systemd hardening.
#   - Controlled filesystem permissions and ACLs.
#   - Deliberate firewall policy.
#   - Logrotate-safe access model.
#   - Persistent journald storage with a 500 MB cap.
#   - Structured health verification.
#   - Final verification with explicit PASS/FAIL assertions.
#
# Required execution:
#   sudo ./kijanikiosk-provision.sh
#
# Target platform:
#   Ubuntu 24.04 LTS / systemd-based Linux
#
# IMPORTANT:
#   All three systemd unit files are intentionally written inline here
#   because that is an explicit requirement of the Week 3 project.
#

set -Eeuo pipefail
IFS=$'\n\t'

###############################################################################
# EXPECTED DIRTY-STATE CONDITIONS
###############################################################################
#
# These conditions were intentionally present during the dirty-state test:
#
# - kk-api service account already existed.
#   Handling: Phase 3 detects the existing account and reconciles its shell
#   and KijaniKiosk group membership without attempting to recreate it.
#
# - /opt/kijanikiosk/config already existed with insecure permissions.
#   Handling: Phase 3 reconciles ownership, permissions and ACLs.
#
# - /opt/kijanikiosk/shared/logs already existed with insecure permissions.
#   Handling: Phase 3 reconciles ownership, permissions and default ACLs.
#
# - UFW was already enabled and contained a historical deny rule for port 3001.
#   Handling: Phase 5 resets UFW to a known baseline before applying the
#   intended KijaniKiosk policy.
#
# - curl was held by APT.
#   Handling: Phase 2 detects the hold, explicitly removes the hold, and then
#   reconciles the required package state.
#
# - /opt/kijanikiosk directory structure was incomplete.
#   Handling: Phase 3 creates and reconciles the complete required structure.
#
###############################################################################

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="1.0.0"

###############################################################################
# GLOBAL CONFIGURATION
###############################################################################

readonly APP_ROOT="/opt/kijanikiosk"
readonly CONFIG_DIR="${APP_ROOT}/config"
readonly SHARED_DIR="${APP_ROOT}/shared"
readonly LOG_DIR="${SHARED_DIR}/logs"
readonly HEALTH_DIR="${APP_ROOT}/health"
readonly RUNTIME_DIR="${APP_ROOT}/runtime"

readonly LOGROTATE_FILE="/etc/logrotate.d/kijanikiosk"
readonly JOURNAL_CONFIG="/etc/systemd/journald.conf.d/kijanikiosk.conf"

readonly API_USER="kk-api"
readonly PAYMENTS_USER="kk-payments"
readonly LOGS_USER="kk-logs"
readonly APP_GROUP="kijanikiosk"

readonly API_PORT="3000"
readonly PAYMENTS_PORT="3001"
readonly LOGS_PORT="3010"

readonly MONITORING_CIDR="10.0.1.0/24"

readonly API_ENV="${CONFIG_DIR}/api.env"
readonly PAYMENTS_ENV="${CONFIG_DIR}/payments-api.env"
readonly LOGS_ENV="${CONFIG_DIR}/logs.env"

readonly API_UNIT="/etc/systemd/system/kk-api.service"
readonly PAYMENTS_UNIT="/etc/systemd/system/kk-payments.service"
readonly LOGS_UNIT="/etc/systemd/system/kk-logs.service"

readonly REQUIRED_PACKAGES=(
    acl
    curl
    jq
    logrotate
    nginx
    ufw
)

FAILED_CHECKS=0

###############################################################################
# LOGGING HELPERS
###############################################################################

timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

log() {
    printf '[%s] INFO: %s\n' "$(timestamp)" "$*"
}

success() {
    printf '[%s] PASS: %s\n' "$(timestamp)" "$*"
}

warn() {
    printf '[%s] WARN: %s\n' "$(timestamp)" "$*" >&2
}

fail() {
    printf '[%s] FAIL: %s\n' "$(timestamp)" "$*" >&2
}

###############################################################################
# ASSERTION HELPERS
###############################################################################

assert_true() {
    local description="$1"
    shift

    if "$@"; then
        success "$description"
    else
        fail "$description"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

assert_file_exists() {
    local path="$1"
    [[ -f "${path}" ]]
}

assert_directory_exists() {
    local path="$1"
    [[ -d "${path}" ]]
}

###############################################################################
# ERROR HANDLING
###############################################################################

on_error() {
    local exit_code=$?
    local line_number="${1:-unknown}"

    fail "Provisioning aborted unexpectedly at line ${line_number} with exit code ${exit_code}."

    exit "${exit_code}"
}

trap 'on_error "${LINENO}"' ERR

###############################################################################
# ROOT CHECK
###############################################################################

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        fail "This script must be executed as root. Use: sudo ./${SCRIPT_NAME}"
        exit 1
    fi
}

###############################################################################
# COMMAND REQUIREMENT CHECK
###############################################################################

require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        fail "Required command is missing: ${command_name}"
        return 1
    fi
}

###############################################################################
# NETWORK / PORT HELPERS
###############################################################################

port_is_listening() {
    local port="$1"

    ss -ltnH 2>/dev/null |
        awk '{print $4}' |
        grep -Eq "(^|:)${port}$"
}

###############################################################################
# SYSTEMD SECURITY SCORE PARSER
###############################################################################

get_security_score() {
    local unit="$1"

    systemd-analyze security "${unit}" 2>/dev/null |
        awk '
            /Overall exposure level/ {
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^[0-9]+([.][0-9]+)?$/) {
                        print $i
                        exit
                    }
                }
            }
        '
}

###############################################################################
# SECURITY SCORE ASSERTION
###############################################################################

check_security_score() {
    local unit="$1"
    local threshold="$2"
    local score

    score="$(get_security_score "${unit}")"

    if [[ -z "${score}" ]]; then
        fail "${unit} security score could not be determined."
        return 1
    fi

    if awk -v score="${score}" -v threshold="${threshold}" \
        'BEGIN { exit !(score < threshold) }'
    then
        success "${unit} security score ${score} is below ${threshold}."
    else
        fail "${unit} security score ${score} is not below ${threshold}."
        return 1
    fi
}

###############################################################################
# PACKAGE HOLD DETECTION
###############################################################################

package_is_held() {
    local package="$1"

    apt-mark showhold 2>/dev/null |
        awk '{print $1}' |
        grep -Fxq "${package}"
}

###############################################################################
# PACKAGE RECONCILIATION
###############################################################################

reconcile_package() {
    local package="$1"

    if package_is_held "${package}"; then
        log "Detected package hold: ${package}; explicitly removing hold."
        apt-mark unhold "${package}"
        success "Removed package hold: ${package}"
    else
        log "No package hold detected for: ${package}"
    fi

    if dpkg-query \
        -W \
        -f='${Status}' \
        "${package}" 2>/dev/null |
        grep -q "install ok installed"
    then
        log "Package already installed: ${package}"
    else
        log "Installing required package: ${package}"
        apt-get install -y "${package}"
    fi
}

###############################################################################
# DIRECTORY RECONCILIATION
###############################################################################

reconcile_directory() {
    local directory="$1"
    local owner="$2"
    local mode="$3"

    if [[ -d "${directory}" ]]; then
        log "Directory already exists: ${directory}; reconciling state."
    else
        log "Creating directory: ${directory}"
        install -d "${directory}"
    fi

    chown "${owner}" "${directory}"
    chmod "${mode}" "${directory}"
}

###############################################################################
# FILE RECONCILIATION
###############################################################################

reconcile_file() {
    local file="$1"
    local owner="$2"
    local mode="$3"

    if [[ -f "${file}" ]]; then
        log "File already exists: ${file}; reconciling state."
    else
        log "Creating file: ${file}"
        touch "${file}"
    fi

    chown "${owner}" "${file}"
    chmod "${mode}" "${file}"
}

###############################################################################
# ACL HELPERS
###############################################################################

require_acl_support() {
    command -v setfacl >/dev/null 2>&1 ||
        {
            fail "setfacl is required but was not found."
            return 1
        }

    command -v getfacl >/dev/null 2>&1 ||
        {
            fail "getfacl is required but was not found."
            return 1
        }
}

###############################################################################
# PHASE 1: PRE-PROVISIONING AUDIT AND PREREQUISITES
###############################################################################

phase_1_audit() {
    log "============================================================"
    log "PHASE 1: Pre-Provisioning Audit and Prerequisites"
    log "============================================================"

    require_root

    local required_commands=(
        apt-get
        apt-mark
        awk
        chmod
        chown
        date
        dpkg-query
        getent
        getfacl
        grep
        install
        jq
        logrotate
        mkdir
        sed
        setfacl
        ss
        systemctl
        systemd-analyze
        ufw
        useradd
        usermod
    )

    for command_name in "${required_commands[@]}"; do
        require_command "${command_name}"
    done

    log "System information:"
    log "  Hostname: $(hostname)"
    log "  Kernel: $(uname -r)"
    log "  User: $(id -un)"
    log "  Script version: ${SCRIPT_VERSION}"

    log "Auditing known dirty-state conditions."

    if id "${API_USER}" >/dev/null 2>&1; then
        log "Dirty-state detected: service account already exists: ${API_USER}"
    else
        log "Clean-state condition: service account does not yet exist: ${API_USER}"
    fi

    if [[ -d "${CONFIG_DIR}" ]]; then
        log "Dirty-state detected: configuration directory already exists: ${CONFIG_DIR}"
    else
        log "Clean-state condition: configuration directory does not exist yet."
    fi

    if [[ -d "${LOG_DIR}" ]]; then
        log "Dirty-state detected: shared log directory already exists: ${LOG_DIR}"
    else
        log "Clean-state condition: shared log directory does not exist yet."
    fi

    if ufw status 2>/dev/null | grep -q "Status: active"; then
        log "Dirty-state detected: UFW is already active."
    else
        log "Clean-state condition: UFW is not currently active."
    fi

    if package_is_held curl; then
        log "Dirty-state detected: curl is currently held by APT."
    else
        log "Clean-state condition: curl is not held by APT."
    fi

    if [[ -d "${APP_ROOT}" ]]; then
        log "Dirty-state detected: KijaniKiosk application root already exists."
    else
        log "Clean-state condition: KijaniKiosk application root does not exist."
    fi

    log "Pre-provisioning audit complete."
}

###############################################################################
# PHASE 2: PACKAGE CONVERGENCE
###############################################################################

phase_2_packages() {
    log "============================================================"
    log "PHASE 2: Package Convergence"
    log "============================================================"

    log "Refreshing APT package metadata."
    apt-get update

    for package in "${REQUIRED_PACKAGES[@]}"; do
        reconcile_package "${package}"
    done

    if package_is_held curl; then
        fail "curl remains held after package reconciliation."
        return 1
    fi

    success "Required package set is installed and package holds have been reconciled."
}

###############################################################################
# PHASE 3: SERVICE ACCOUNTS, DIRECTORIES, ACLS AND CONFIGURATION
###############################################################################

phase_3_identity_and_filesystem() {
    log "============================================================"
    log "PHASE 3: Service Accounts, Directories, ACLs and Configuration"
    log "============================================================"

    ###########################################################################
    # Application group
    ###########################################################################

    if getent group "${APP_GROUP}" >/dev/null 2>&1; then
        log "Application group already exists: ${APP_GROUP}"
    else
        log "Creating application group: ${APP_GROUP}"
        groupadd --system "${APP_GROUP}"
    fi

    ###########################################################################
    # Service accounts
    ###########################################################################

    for service_user in \
        "${API_USER}" \
        "${PAYMENTS_USER}" \
        "${LOGS_USER}"
    do
        if id "${service_user}" >/dev/null 2>&1; then
            log "Existing service account already exists: ${service_user}; reconciling it."

            if ! getent passwd "${service_user}" >/dev/null 2>&1; then
                fail "Service account ${service_user} exists but cannot be resolved through NSS."
                return 1
            fi

            # usermod does not support useradd's --no-create-home option.
            # Existing accounts are therefore reconciled without attempting
            # to recreate or delete their existing home directory.
            usermod \
                --shell /usr/sbin/nologin \
                "${service_user}"

            if ! id -nG "${service_user}" |
                tr ' ' '\n' |
                grep -Fxq "${APP_GROUP}"
            then
                log "Adding ${service_user} to ${APP_GROUP}."
                usermod \
                    --append \
                    --groups "${APP_GROUP}" \
                    "${service_user}"
            else
                log "${service_user} is already a member of ${APP_GROUP}."
            fi

            if [[ "$(getent passwd "${service_user}" | cut -d: -f7)" != "/usr/sbin/nologin" ]]; then
                fail "Failed to reconcile login shell for ${service_user}."
                return 1
            fi

            if ! id -nG "${service_user}" |
                tr ' ' '\n' |
                grep -Fxq "${APP_GROUP}"
            then
                fail "Failed to reconcile group membership for ${service_user}."
                return 1
            fi

            success "Reconciled existing service account: ${service_user}"
        else
            log "Creating service account: ${service_user}"

            useradd \
                --system \
                --no-create-home \
                --shell /usr/sbin/nologin \
                --gid "${APP_GROUP}" \
                "${service_user}"

            success "Created service account: ${service_user}"
        fi
    done

    ###########################################################################
    # Final account verification
    ###########################################################################

    for service_user in \
        "${API_USER}" \
        "${PAYMENTS_USER}" \
        "${LOGS_USER}"
    do
        if ! id "${service_user}" >/dev/null 2>&1; then
            fail "Service account verification failed: ${service_user}"
            return 1
        fi

        if [[ "$(getent passwd "${service_user}" | cut -d: -f7)" != "/usr/sbin/nologin" ]]; then
            fail "Service account ${service_user} does not use /usr/sbin/nologin."
            return 1
        fi

        if ! id -nG "${service_user}" |
            tr ' ' '\n' |
            grep -Fxq "${APP_GROUP}"
        then
            fail "Service account ${service_user} is not a member of ${APP_GROUP}."
            return 1
        fi

        service_uid="$(id -u "${service_user}")"

        if [[ "${service_uid}" =~ ^[0-9]+$ ]]; then
            log "Verified ${service_user} UID: ${service_uid}"
        else
            fail "Unable to determine numeric UID for ${service_user}."
            return 1
        fi
    done

    ###########################################################################
    # Directory structure
    ###########################################################################

    reconcile_directory \
        "${APP_ROOT}" \
        "root:${APP_GROUP}" \
        "0750"

    reconcile_directory \
        "${CONFIG_DIR}" \
        "root:${APP_GROUP}" \
        "0750"

    reconcile_directory \
        "${SHARED_DIR}" \
        "${LOGS_USER}:${APP_GROUP}" \
        "2770"

    reconcile_directory \
        "${LOG_DIR}" \
        "${LOGS_USER}:${APP_GROUP}" \
        "2770"

    reconcile_directory \
        "${HEALTH_DIR}" \
        "${LOGS_USER}:${APP_GROUP}" \
        "0750"

    reconcile_directory \
        "${RUNTIME_DIR}" \
        "root:${APP_GROUP}" \
        "0750"

    ###########################################################################
    # Directory ACL model
    ###########################################################################

    require_acl_support

    log "Reconciling ACLs on shared log directory."

    setfacl -b "${LOG_DIR}"

    setfacl -m \
        "u:${API_USER}:rwx" \
        "u:${PAYMENTS_USER}:rx" \
        "u:${LOGS_USER}:rwx" \
        "g:${APP_GROUP}:r-x" \
        "m::rwx" \
        "${LOG_DIR}"

    setfacl -d -m \
        "u::rwx" \
        "u:${API_USER}:rwx" \
        "u:${PAYMENTS_USER}:r-x" \
        "g::r-x" \
        "g:${APP_GROUP}:r-x" \
        "m::rwx" \
        "o::---" \
        "${LOG_DIR}"

    log "Reconciling ACLs on configuration directory."

    setfacl -b "${CONFIG_DIR}"

    setfacl -m \
        "u:${API_USER}:rx" \
        "u:${PAYMENTS_USER}:rx" \
        "u:${LOGS_USER}:rx" \
        "g:${APP_GROUP}:r-x" \
        "m::r-x" \
        "${CONFIG_DIR}"

    log "Reconciling ACLs on health directory."

    setfacl -b "${HEALTH_DIR}"

    setfacl -m \
        "u:${LOGS_USER}:rwx" \
        "g:${APP_GROUP}:r-x" \
        "m::rwx" \
        "${HEALTH_DIR}"

    ###########################################################################
    # Environment files
    ###########################################################################

    log "Creating/reconciling API environment file."

    cat > "${API_ENV}" <<'EOF'
KK_SERVICE=api
KK_PORT=3000
EOF

    chown "root:${APP_GROUP}" "${API_ENV}"
    chmod 0640 "${API_ENV}"

    setfacl -m \
        "u:${API_USER}:r" \
        "u:${PAYMENTS_USER}:r" \
        "u:${LOGS_USER}:r" \
        "g:${APP_GROUP}:r--" \
        "m::r--" \
        "${API_ENV}"

    log "Creating/reconciling payments environment file."

    cat > "${PAYMENTS_ENV}" <<'EOF'
KK_SERVICE=payments
KK_PORT=3001
KK_API_URL=http://127.0.0.1:3000
EOF

    chown "root:${APP_GROUP}" "${PAYMENTS_ENV}"
    chmod 0640 "${PAYMENTS_ENV}"

    setfacl -m \
        "u:${PAYMENTS_USER}:r" \
        "u:${API_USER}:r" \
        "u:${LOGS_USER}:r" \
        "g:${APP_GROUP}:r--" \
        "m::r--" \
        "${PAYMENTS_ENV}"

    log "Creating/reconciling logs environment file."

    cat > "${LOGS_ENV}" <<'EOF'
KK_SERVICE=logs
KK_LOG_DIRECTORY=/opt/kijanikiosk/shared/logs
EOF

    chown "root:${APP_GROUP}" "${LOGS_ENV}"
    chmod 0640 "${LOGS_ENV}"

    setfacl -m \
        "u:${LOGS_USER}:r" \
        "u:${API_USER}:r" \
        "u:${PAYMENTS_USER}:r" \
        "g:${APP_GROUP}:r--" \
        "m::r--" \
        "${LOGS_ENV}"

    ###########################################################################
    # Configuration readability verification
    ###########################################################################

    if ! sudo -u "${PAYMENTS_USER}" cat "${PAYMENTS_ENV}" >/dev/null; then
        fail "kk-payments cannot read its EnvironmentFile."
        return 1
    fi

    if ! sudo -u "${API_USER}" cat "${API_ENV}" >/dev/null; then
        fail "kk-api cannot read its EnvironmentFile."
        return 1
    fi

    if ! sudo -u "${LOGS_USER}" cat "${LOGS_ENV}" >/dev/null; then
        fail "kk-logs cannot read its EnvironmentFile."
        return 1
    fi

    success "Service accounts, filesystem ownership, permissions, ACLs and environment files reconciled."
}

###############################################################################
# PHASE 4: SYSTEMD SERVICES AND HARDENING
###############################################################################

phase_4_systemd() {
    log "============================================================"
    log "PHASE 4: systemd Services and Security Hardening"
    log "============================================================"

    ###########################################################################
    # kk-api.service
    ###########################################################################

    log "Writing ${API_UNIT}."

    cat > "${API_UNIT}" <<EOF
[Unit]
Description=KijaniKiosk API Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${API_USER}
Group=${APP_GROUP}
EnvironmentFile=${API_ENV}
WorkingDirectory=${RUNTIME_DIR}
ExecStart=/usr/bin/python3 -m http.server ${API_PORT} --bind 127.0.0.1
Restart=on-failure
RestartSec=3

# Privilege and filesystem restrictions.
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict

# Kernel and control-plane protection.
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true

# Process and namespace protection.
ProtectProc=invisible
ProcSubset=pid
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true

# Runtime attack-surface reduction.
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictAddressFamilies=AF_INET AF_INET6

# Linux capability and syscall restrictions.
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "${API_UNIT}"

    ###########################################################################
    # kk-payments.service
    ###########################################################################

    log "Writing ${PAYMENTS_UNIT}."

    cat > "${PAYMENTS_UNIT}" <<EOF
[Unit]
Description=KijaniKiosk Payments Service
After=network-online.target kk-api.service
Wants=network-online.target kk-api.service

[Service]
Type=simple
User=${PAYMENTS_USER}
Group=${APP_GROUP}
EnvironmentFile=${PAYMENTS_ENV}
WorkingDirectory=${RUNTIME_DIR}
ExecStart=/usr/bin/python3 -m http.server ${PAYMENTS_PORT} --bind 127.0.0.1
Restart=on-failure
RestartSec=3

# Privilege and filesystem restrictions.
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict

# Kernel and control-plane protection.
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true

# Process and namespace protection.
ProtectProc=invisible
ProcSubset=pid
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true

# Runtime attack-surface reduction.
MemoryDenyWriteExecute=true
RestrictRealtime=true

# The service only needs IPv4/IPv6 TCP sockets.
# AF_UNIX is deliberately excluded because this service does not require it.
RestrictAddressFamilies=AF_INET AF_INET6

# Linux capability and syscall restrictions.
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug

# Prevent the service from leaving IPC objects behind.
RemoveIPC=true

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "${PAYMENTS_UNIT}"

    ###########################################################################
    # kk-logs.service
    ###########################################################################

    log "Writing ${LOGS_UNIT}."

    cat > "${LOGS_UNIT}" <<EOF
[Unit]
Description=KijaniKiosk Logs Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${LOGS_USER}
Group=${APP_GROUP}
EnvironmentFile=${LOGS_ENV}
WorkingDirectory=${RUNTIME_DIR}
ExecStart=/usr/bin/python3 -m http.server ${LOGS_PORT} --bind 127.0.0.1
Restart=on-failure
RestartSec=3

# Privilege and filesystem restrictions.
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectSystem=strict

# Kernel and control-plane protection.
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectHostname=true

# Process and namespace protection.
ProtectProc=invisible
ProcSubset=pid
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true

# Runtime attack-surface reduction.
MemoryDenyWriteExecute=true
RestrictRealtime=true
RestrictAddressFamilies=AF_INET AF_INET6

# Linux capability and syscall restrictions.
CapabilityBoundingSet=
AmbientCapabilities=
SystemCallArchitectures=native
SystemCallFilter=~@clock @cpu-emulation @debug
RemoveIPC=true

[Install]
WantedBy=multi-user.target
EOF

    chmod 0644 "${LOGS_UNIT}"

    ###########################################################################
    # Validate all unit files before starting anything.
    ###########################################################################

    log "Validating systemd unit syntax."

    for unit_file in \
        "${API_UNIT}" \
        "${PAYMENTS_UNIT}" \
        "${LOGS_UNIT}"
    do
        if ! systemd-analyze verify "${unit_file}"; then
            fail "systemd unit validation failed: ${unit_file}"
            return 1
        fi

        success "Validated systemd unit: ${unit_file}"
    done

    systemctl daemon-reload

    ###########################################################################
    # Verify EnvironmentFiles exist and are readable by service users.
    ###########################################################################

    for service_user in \
        "${API_USER}" \
        "${PAYMENTS_USER}" \
        "${LOGS_USER}"
    do
        case "${service_user}" in
            "${API_USER}")
                environment_file="${API_ENV}"
                ;;
            "${PAYMENTS_USER}")
                environment_file="${PAYMENTS_ENV}"
                ;;
            "${LOGS_USER}")
                environment_file="${LOGS_ENV}"
                ;;
        esac

        if [[ ! -r "${environment_file}" ]]; then
            fail "${environment_file} does not exist or is not readable."
            return 1
        fi

        if ! sudo -u "${service_user}" cat "${environment_file}" >/dev/null; then
            fail "${service_user} cannot read ${environment_file}."
            return 1
        fi

        success "${service_user} can read ${environment_file}."
    done

    ###########################################################################
    # Security thresholds.
    ###########################################################################

    log "Evaluating systemd security exposure."

    check_security_score \
        "kk-api.service" \
        "3.5"

    check_security_score \
        "kk-payments.service" \
        "2.5"

    check_security_score \
        "kk-logs.service" \
        "3.5"

    ###########################################################################
    # Dependency verification.
    ###########################################################################

    if systemctl cat kk-payments.service |
        grep -Eq '^After=.*kk-api\.service'
    then
        success "kk-payments.service declares After=kk-api.service."
    else
        fail "kk-payments.service is missing After=kk-api.service."
        return 1
    fi

    if systemctl cat kk-payments.service |
        grep -Eq '^Wants=.*kk-api\.service'
    then
        success "kk-payments.service declares Wants=kk-api.service."
    else
        fail "kk-payments.service is missing Wants=kk-api.service."
        return 1
    fi

    ###########################################################################
    # Enable and start services.
    ###########################################################################

    systemctl enable kk-api.service
    systemctl enable kk-payments.service
    systemctl enable kk-logs.service

    systemctl restart kk-api.service
    systemctl restart kk-payments.service
    systemctl restart kk-logs.service

    sleep 3

    ###########################################################################
    # Service startup verification.
    ###########################################################################

    for unit in \
        kk-api.service \
        kk-payments.service \
        kk-logs.service
    do
        if systemctl is-active --quiet "${unit}"; then
            success "${unit} is active."
        else
            fail "${unit} failed to start."

            log "systemctl status for ${unit}:"
            systemctl status "${unit}" --no-pager || true

            log "Recent journal for ${unit}:"
            journalctl \
                -u "${unit}" \
                -n 50 \
                --no-pager || true

            return 1
        fi
    done

    success "All three KijaniKiosk systemd services started successfully."
}

###############################################################################
# PHASE 5: FIREWALL POLICY
###############################################################################

phase_5_firewall() {
    log "============================================================"
    log "PHASE 5: Firewall Policy"
    log "============================================================"

    ###########################################################################
    # Reset historical state.
    ###########################################################################

    log "Resetting UFW to a known baseline."

    ufw --force reset

    ###########################################################################
    # Default policy.
    ###########################################################################

    ufw default deny incoming
    ufw default allow outgoing

    ###########################################################################
    # Required rules.
    ###########################################################################

    ufw allow \
        22/tcp \
        comment 'KijaniKiosk administrative SSH access'

    ufw allow \
        80/tcp \
        comment 'KijaniKiosk HTTP web traffic'

    ufw allow \
        from "${MONITORING_CIDR}" \
        to any \
        port "${PAYMENTS_PORT}" \
        proto tcp \
        comment 'KijaniKiosk payments monitoring subnet health access'

    # Loopback must be allowed before the explicit external deny.
    ufw allow \
        in on lo \
        to any \
        port "${PAYMENTS_PORT}" \
        proto tcp \
        comment 'KijaniKiosk local loopback payments proxy access'

    ufw deny \
        "${PAYMENTS_PORT}/tcp" \
        comment 'KijaniKiosk block external payments service access'

    ufw --force enable

    ###########################################################################
    # Capture final rules.
    ###########################################################################

    local firewall_status
    local firewall_added

    firewall_status="$(ufw status numbered)"
    firewall_added="$(ufw show added)"

    log "Final UFW status:"
    printf '%s\n' "${firewall_status}"

    log "Configured UFW rules:"
    printf '%s\n' "${firewall_added}"

    ###########################################################################
    # One PASS/FAIL assertion per required rule.
    ###########################################################################

    if grep -qE '22/tcp[[:space:]]+ALLOW' <<< "${firewall_status}" &&
        grep -q 'KijaniKiosk administrative SSH access' <<< "${firewall_added}"
    then
        success "UFW rule assertion: SSH 22/tcp is allowed and commented."
    else
        fail "UFW rule assertion: SSH 22/tcp is missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE '80/tcp[[:space:]]+ALLOW' <<< "${firewall_status}" &&
        grep -q 'KijaniKiosk HTTP web traffic' <<< "${firewall_added}"
    then
        success "UFW rule assertion: HTTP 80/tcp is allowed and commented."
    else
        fail "UFW rule assertion: HTTP 80/tcp is missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE "${PAYMENTS_PORT}/tcp.*ALLOW.*${MONITORING_CIDR}" \
        <<< "${firewall_status}" &&
        grep -q 'KijaniKiosk payments monitoring subnet health access' \
        <<< "${firewall_added}"
    then
        success "UFW rule assertion: monitoring subnet can access payments health port."
    else
        fail "UFW rule assertion: monitoring subnet payments rule is missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE "${PAYMENTS_PORT}/tcp.*ALLOW.*lo" \
        <<< "${firewall_status}" &&
        grep -q 'KijaniKiosk local loopback payments proxy access' \
        <<< "${firewall_added}"
    then
        success "UFW rule assertion: loopback access to payments port is allowed."
    else
        fail "UFW rule assertion: loopback payments rule is missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE "${PAYMENTS_PORT}/tcp.*DENY" \
        <<< "${firewall_status}" &&
        grep -q 'KijaniKiosk block external payments service access' \
        <<< "${firewall_added}"
    then
        success "UFW rule assertion: external payments access is explicitly denied."
    else
        fail "UFW rule assertion: external payments deny rule is missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Verify loopback appears before the deny rule.
    ###########################################################################

    local loopback_line
    local deny_line

    loopback_line="$(
        awk '
            /KijaniKiosk local loopback payments proxy access/ {
                print NR
                exit
            }
        ' <<< "${firewall_status}"
    )"

    deny_line="$(
        awk '
            /KijaniKiosk block external payments service access/ {
                print NR
                exit
            }
        ' <<< "${firewall_status}"
    )"

    if [[ -n "${loopback_line}" ]] &&
        [[ -n "${deny_line}" ]] &&
        (( loopback_line < deny_line ))
    then
        success "UFW ordering assertion: loopback allow appears before external deny."
    else
        fail "UFW ordering assertion: loopback allow must appear before external deny."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

###############################################################################
# PHASE 6: LOGROTATE ACCESS MODEL
###############################################################################

phase_6_logrotate() {
    log "============================================================"
    log "PHASE 6: Logrotate Access Model"
    log "============================================================"

    ###########################################################################
    # Create the three application log files.
    ###########################################################################

    for logfile in \
        "${LOG_DIR}/kk-api.log" \
        "${LOG_DIR}/kk-payments.log" \
        "${LOG_DIR}/kk-logs.log"
    do
        if [[ -f "${logfile}" ]]; then
            log "Log file already exists: ${logfile}"
        else
            log "Creating log file: ${logfile}"
            touch "${logfile}"
        fi

        chown "${LOGS_USER}:${APP_GROUP}" "${logfile}"
        chmod 0660 "${logfile}"

        setfacl -m \
            "u:${API_USER}:rw" \
            "u:${PAYMENTS_USER}:r" \
            "u:${LOGS_USER}:rw" \
            "g:${APP_GROUP}:rw" \
            "m::rw" \
            "${logfile}"
    done

    ###########################################################################
    # Write logrotate policy.
    ###########################################################################

    log "Writing ${LOGROTATE_FILE}."

    cat > "${LOGROTATE_FILE}" <<'ROTATE'
/opt/kijanikiosk/shared/logs/kk-api.log
/opt/kijanikiosk/shared/logs/kk-payments.log
/opt/kijanikiosk/shared/logs/kk-logs.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    su kk-logs kijanikiosk
    create 0660 kk-logs kijanikiosk
    sharedscripts
    postrotate
        for logfile in \
            /opt/kijanikiosk/shared/logs/kk-api.log \
            /opt/kijanikiosk/shared/logs/kk-payments.log \
            /opt/kijanikiosk/shared/logs/kk-logs.log
        do
            if [ -e "$logfile" ]; then
                setfacl \
                    -m \
                    u:kk-api:rw, \
                    u:kk-payments:r, \
                    u:kk-logs:rw, \
                    g:kijanikiosk:rw, \
                    m::rw \
                    "$logfile"
            fi
        done

        systemctl restart kk-logs.service
    endscript
}
ROTATE

    chmod 0644 "${LOGROTATE_FILE}"

    ###########################################################################
    # Debug validation.
    ###########################################################################

    log "Running logrotate debug validation."

    if logrotate --debug "${LOGROTATE_FILE}" >/tmp/kijanikiosk-logrotate-debug.txt 2>&1; then
        success "logrotate --debug passed."
    else
        fail "logrotate --debug failed."
        cat /tmp/kijanikiosk-logrotate-debug.txt >&2
        return 1
    fi

    ###########################################################################
    # Force actual rotation.
    ###########################################################################

    log "Forcing an actual log rotation."

    if ! logrotate --force "${LOGROTATE_FILE}"; then
        fail "Forced logrotate execution failed."
        return 1
    fi

    ###########################################################################
    # Verify recreated files.
    ###########################################################################

    for logfile in \
        "${LOG_DIR}/kk-api.log" \
        "${LOG_DIR}/kk-payments.log" \
        "${LOG_DIR}/kk-logs.log"
    do
        if [[ ! -f "${logfile}" ]]; then
            fail "Expected rotated log file was not recreated: ${logfile}"
            return 1
        fi

        chown "${LOGS_USER}:${APP_GROUP}" "${logfile}"
        chmod 0660 "${logfile}"

        setfacl -m \
            "u:${API_USER}:rw" \
            "u:${PAYMENTS_USER}:r" \
            "u:${LOGS_USER}:rw" \
            "g:${APP_GROUP}:rw" \
            "m::rw" \
            "${logfile}"
    done

    ###########################################################################
    # Definitive required post-rotation write test.
    ###########################################################################

    log "Running definitive post-logrotate access test."

    if sudo -u "${API_USER}" \
        touch "${LOG_DIR}/test-write.tmp"
    then
        success "kk-api can write after logrotate."
    else
        fail "kk-api cannot write to shared/logs after logrotate."
        return 1
    fi

    rm -f "${LOG_DIR}/test-write.tmp"

    success "Logrotate configuration and post-rotation access model verified."
}

###############################################################################
# PHASE 7: JOURNAL PERSISTENCE AND LOG ROTATION VERIFICATION
###############################################################################

phase_7_journal() {
    log "============================================================"
    log "PHASE 7: Journal Persistence and Log Rotation Verification"
    log "============================================================"

    ###########################################################################
    # Persistent journal directory.
    ###########################################################################

    if [[ -d /var/log/journal ]]; then
        log "Persistent journal directory already exists."
    else
        log "Creating persistent journal directory."
        mkdir -p /var/log/journal
    fi

    chown root:systemd-journal /var/log/journal
    chmod 2755 /var/log/journal

    ###########################################################################
    # Journald configuration directory.
    ###########################################################################

    mkdir -p "$(dirname "${JOURNAL_CONFIG}")"

    ###########################################################################
    # Journald configuration.
    ###########################################################################

    cat > "${JOURNAL_CONFIG}" <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
RuntimeMaxUse=100M
EOF

    chmod 0644 "${JOURNAL_CONFIG}"

    ###########################################################################
    # Restart journald and flush runtime journal.
    ###########################################################################

    systemctl restart systemd-journald
    journalctl --flush

    ###########################################################################
    # Verify persistent journal configuration.
    ###########################################################################

    if grep -q '^Storage=persistent$' "${JOURNAL_CONFIG}"; then
        success "Journald persistent storage is configured."
    else
        fail "Journald persistent storage configuration is missing."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -q '^SystemMaxUse=500M$' "${JOURNAL_CONFIG}"; then
        success "Journald persistent storage cap is configured at 500M."
    else
        fail "Journald 500M storage cap is missing."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if [[ -d /var/log/journal ]]; then
        success "Persistent journal directory exists."
    else
        fail "Persistent journal directory does not exist."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Re-run logrotate debug verification as part of the required combined
    # journal/log-rotation verification phase.
    ###########################################################################

    if logrotate --debug "${LOGROTATE_FILE}" \
        >/tmp/kijanikiosk-logrotate-phase7-debug.txt 2>&1
    then
        success "Phase 7 logrotate debug verification passed."
    else
        fail "Phase 7 logrotate debug verification failed."
        cat /tmp/kijanikiosk-logrotate-phase7-debug.txt >&2
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Report current journal usage.
    ###########################################################################

    log "Current journal disk usage:"
    journalctl --disk-usage || true
}

###############################################################################
# PHASE 8: MONITORING HEALTH CHECKS AND FINAL VERIFICATION
###############################################################################

phase_8_health_and_verification() {
    log "============================================================"
    log "PHASE 8: Monitoring Health Checks and Final Verification"
    log "============================================================"

    ###########################################################################
    # Verify service states.
    ###########################################################################

    for unit in \
        kk-api.service \
        kk-payments.service \
        kk-logs.service
    do
        if systemctl is-active --quiet "${unit}"; then
            success "Service state assertion: ${unit} is active."
        else
            fail "Service state assertion: ${unit} is not active."
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi

        if systemctl is-enabled --quiet "${unit}"; then
            success "Service enablement assertion: ${unit} is enabled."
        else
            fail "Service enablement assertion: ${unit} is not enabled."
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done

    ###########################################################################
    # Verify ports.
    ###########################################################################

    local api_status
    local payments_status
    local logs_status

    if port_is_listening "${API_PORT}"; then
        api_status='"ok"'
        success "Port assertion: ${API_PORT} is listening."
    else
        api_status='"down"'
        fail "Port assertion: ${API_PORT} is not listening."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if port_is_listening "${PAYMENTS_PORT}"; then
        payments_status='"ok"'
        success "Port assertion: ${PAYMENTS_PORT} is listening."
    else
        payments_status='"down"'
        fail "Port assertion: ${PAYMENTS_PORT} is not listening."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if port_is_listening "${LOGS_PORT}"; then
        logs_status='"ok"'
        success "Port assertion: ${LOGS_PORT} is listening."
    else
        logs_status='"down"'
        fail "Port assertion: ${LOGS_PORT} is not listening."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Health JSON.
    ###########################################################################

    mkdir -p "${HEALTH_DIR}"

    local health_file="${HEALTH_DIR}/last-provision.json"

    printf \
        '{"timestamp":"%s","kk-api":{"port":%s,"status":%s},"kk-payments":{"port":%s,"status":%s},"kk-logs":{"port":%s,"status":%s}}\n' \
        "$(date -Is)" \
        "${API_PORT}" "${api_status}" \
        "${PAYMENTS_PORT}" "${payments_status}" \
        "${LOGS_PORT}" "${logs_status}" \
        > "${health_file}"

    chown "${LOGS_USER}:${APP_GROUP}" "${health_file}"
    chmod 0640 "${health_file}"

    setfacl -m \
        "u:${LOGS_USER}:rw" \
        "g:${APP_GROUP}:r--" \
        "m::r--" \
        "${health_file}"

    if [[ -f "${health_file}" ]]; then
        success "Health JSON exists: ${health_file}"
    else
        fail "Health JSON does not exist."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if jq empty "${health_file}" >/dev/null 2>&1; then
        success "Health JSON is valid structured JSON."
    else
        fail "Health JSON is not valid JSON."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if sudo -u "${PAYMENTS_USER}" cat "${health_file}" >/dev/null; then
        success "Health JSON is readable by the KijaniKiosk service group."
    else
        fail "Health JSON is not readable by the KijaniKiosk service group."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Payments dependency verification.
    ###########################################################################

    if systemctl show \
        kk-payments.service \
        --property=After \
        --value |
        tr ' ' '\n' |
        grep -Fxq 'kk-api.service'
    then
        success "Payments dependency assertion: kk-payments has After=kk-api.service."
    else
        fail "Payments dependency assertion: kk-payments is missing After=kk-api.service."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if systemctl show \
        kk-payments.service \
        --property=Wants \
        --value |
        tr ' ' '\n' |
        grep -Fxq 'kk-api.service'
    then
        success "Payments dependency assertion: kk-payments has Wants=kk-api.service."
    else
        fail "Payments dependency assertion: kk-payments is missing Wants=kk-api.service."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Final security score verification.
    ###########################################################################

    if check_security_score "kk-api.service" "3.5"; then
        :
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if check_security_score "kk-payments.service" "2.5"; then
        :
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if check_security_score "kk-logs.service" "3.5"; then
        :
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Unit validation.
    ###########################################################################

    for unit_file in \
        "${API_UNIT}" \
        "${PAYMENTS_UNIT}" \
        "${LOGS_UNIT}"
    do
        if systemd-analyze verify "${unit_file}" >/dev/null 2>&1; then
            success "Final systemd validation passed: ${unit_file}"
        else
            fail "Final systemd validation failed: ${unit_file}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done

    ###########################################################################
    # Environment file verification.
    ###########################################################################

    for environment_file in \
        "${API_ENV}" \
        "${PAYMENTS_ENV}" \
        "${LOGS_ENV}"
    do
        if [[ -r "${environment_file}" ]]; then
            success "Environment file exists and is readable: ${environment_file}"
        else
            fail "Environment file missing or unreadable: ${environment_file}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
    done

    ###########################################################################
    # Logrotate verification.
    ###########################################################################

    if [[ -f "${LOGROTATE_FILE}" ]]; then
        success "Logrotate configuration exists."
    else
        fail "Logrotate configuration is missing."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if logrotate --debug "${LOGROTATE_FILE}" \
        >/tmp/kijanikiosk-final-logrotate-debug.txt 2>&1
    then
        success "Final logrotate debug verification passed."
    else
        fail "Final logrotate debug verification failed."
        cat /tmp/kijanikiosk-final-logrotate-debug.txt >&2
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Post-rotation write verification.
    ###########################################################################

    if sudo -u "${API_USER}" \
        touch "${LOG_DIR}/test-write.tmp"
    then
        success "Post-rotation access assertion: kk-api can write after logrotate."
        rm -f "${LOG_DIR}/test-write.tmp"
    else
        fail "Post-rotation access assertion: kk-api cannot write after logrotate."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Firewall verification.
    ###########################################################################

    local final_firewall_status
    local final_firewall_added

    final_firewall_status="$(ufw status numbered)"
    final_firewall_added="$(ufw show added)"

    if grep -qE '22/tcp[[:space:]]+ALLOW' \
        <<< "${final_firewall_status}" &&
        grep -q 'KijaniKiosk administrative SSH access' \
        <<< "${final_firewall_added}"
    then
        success "Final firewall assertion: SSH rule present and commented."
    else
        fail "Final firewall assertion: SSH rule missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE '80/tcp[[:space:]]+ALLOW' \
        <<< "${final_firewall_status}" &&
        grep -q 'KijaniKiosk HTTP web traffic' \
        <<< "${final_firewall_added}"
    then
        success "Final firewall assertion: HTTP rule present and commented."
    else
        fail "Final firewall assertion: HTTP rule missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE "${PAYMENTS_PORT}/tcp.*ALLOW.*${MONITORING_CIDR}" \
        <<< "${final_firewall_status}" &&
        grep -q 'KijaniKiosk payments monitoring subnet health access' \
        <<< "${final_firewall_added}"
    then
        success "Final firewall assertion: monitoring subnet rule present and commented."
    else
        fail "Final firewall assertion: monitoring subnet rule missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE "${PAYMENTS_PORT}/tcp.*ALLOW.*lo" \
        <<< "${final_firewall_status}" &&
        grep -q 'KijaniKiosk local loopback payments proxy access' \
        <<< "${final_firewall_added}"
    then
        success "Final firewall assertion: loopback payments rule present and commented."
    else
        fail "Final firewall assertion: loopback payments rule missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -qE "${PAYMENTS_PORT}/tcp.*DENY" \
        <<< "${final_firewall_status}" &&
        grep -q 'KijaniKiosk block external payments service access' \
        <<< "${final_firewall_added}"
    then
        success "Final firewall assertion: external payments deny rule present and commented."
    else
        fail "Final firewall assertion: external payments deny rule missing or uncommented."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Loopback functional test.
    ###########################################################################

    if timeout 3 bash -c \
        "echo >/dev/tcp/127.0.0.1/${PAYMENTS_PORT}" \
        >/dev/null 2>&1
    then
        success "Functional firewall assertion: localhost can reach payments port."
    else
        fail "Functional firewall assertion: localhost cannot reach payments port."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # External-address test.
    ###########################################################################

    local primary_ip

    primary_ip="$(
        ip -4 route get 1.1.1.1 2>/dev/null |
            awk '
                {
                    for (i = 1; i <= NF; i++) {
                        if ($i == "src") {
                            print $(i + 1)
                            exit
                        }
                    }
                }
            '
    )"

    if [[ -n "${primary_ip}" ]]; then
        log "Testing payments port through primary host address: ${primary_ip}"

        if timeout 3 bash -c \
            "echo >/dev/tcp/${primary_ip}/${PAYMENTS_PORT}" \
            >/dev/null 2>&1
        then
            fail "Functional firewall assertion: external host address reached payments port ${PAYMENTS_PORT}."
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            success "Functional firewall assertion: payments port is not reachable through external host address."
        fi
    else
        warn "Unable to determine primary IPv4 address for external-address firewall test."
        warn "Manual external firewall verification is required."
    fi

    ###########################################################################
    # Journal verification.
    ###########################################################################

    if [[ -d /var/log/journal ]]; then
        success "Final journal assertion: persistent journal directory exists."
    else
        fail "Final journal assertion: persistent journal directory does not exist."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if grep -q '^SystemMaxUse=500M$' "${JOURNAL_CONFIG}"; then
        success "Final journal assertion: persistent journal cap is 500M."
    else
        fail "Final journal assertion: persistent journal cap is not 500M."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Filesystem ownership verification.
    ###########################################################################

    if [[ "$(stat -c '%U:%G' "${APP_ROOT}")" == "root:${APP_GROUP}" ]]; then
        success "Filesystem assertion: application root ownership is correct."
    else
        fail "Filesystem assertion: application root ownership is incorrect."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if [[ "$(stat -c '%U:%G' "${CONFIG_DIR}")" == "root:${APP_GROUP}" ]]; then
        success "Filesystem assertion: configuration directory ownership is correct."
    else
        fail "Filesystem assertion: configuration directory ownership is incorrect."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if [[ "$(stat -c '%U:%G' "${LOG_DIR}")" == "${LOGS_USER}:${APP_GROUP}" ]]; then
        success "Filesystem assertion: shared log directory ownership is correct."
    else
        fail "Filesystem assertion: shared log directory ownership is incorrect."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    if [[ "$(stat -c '%U:%G' "${HEALTH_DIR}")" == "${LOGS_USER}:${APP_GROUP}" ]]; then
        success "Filesystem assertion: health directory ownership is correct."
    else
        fail "Filesystem assertion: health directory ownership is incorrect."
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi

    ###########################################################################
    # Final result.
    ###########################################################################

    log "============================================================"
    log "FINAL VERIFICATION RESULT"
    log "============================================================"

    if [[ "${FAILED_CHECKS}" -eq 0 ]]; then
        success "ALL FINAL VERIFICATION CHECKS PASSED."
        success "KijaniKiosk provisioning completed successfully."
        return 0
    fi

    fail "FINAL VERIFICATION FAILED: ${FAILED_CHECKS} check(s) failed."
    return 1
}

###############################################################################
# MAIN EXECUTION
###############################################################################

main() {
    log "Starting ${SCRIPT_NAME} version ${SCRIPT_VERSION}."

    phase_1_audit
    phase_2_packages
    phase_3_identity_and_filesystem
    phase_4_systemd
    phase_5_firewall
    phase_6_logrotate
    phase_7_journal
    phase_8_health_and_verification

    log "Provisioning completed successfully."
}

main "$@"
