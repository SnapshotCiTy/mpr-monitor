#!/bin/sh

# mpr-monitor data collector
# Detects all mpr controllers and logs sysctl values to per-controller CSV files

DATA_DIR="/var/log/mpr_monitor"
INTERVAL=60

mkdir -p "${DATA_DIR}"

# Detect which mpr controllers exist
detect_controllers() {
    controllers=""
    for i in 0 1 2 3 4 5; do
        if sysctl -n dev.mpr.${i}.chain_free > /dev/null 2>&1; then
            controllers="${controllers} ${i}"
        fi
    done
    echo ${controllers}
}

# Write CSV header if file is new
init_csv() {
    local idx=$1
    local csv="${DATA_DIR}/mpr${idx}_stats.csv"
    if [ ! -f "${csv}" ]; then
        echo "timestamp,chain_free,chain_free_lowwater,chain_alloc_fail,io_cmds_active,io_cmds_highwater" > "${csv}"
        chmod 644 "${csv}"
    fi
}

# Collect one sample for a controller
collect() {
    local idx=$1
    local csv="${DATA_DIR}/mpr${idx}_stats.csv"
    echo "$(date +%Y-%m-%dT%H:%M:%S),$(sysctl -n dev.mpr.${idx}.chain_free),$(sysctl -n dev.mpr.${idx}.chain_free_lowwater),$(sysctl -n dev.mpr.${idx}.chain_alloc_fail),$(sysctl -n dev.mpr.${idx}.io_cmds_active),$(sysctl -n dev.mpr.${idx}.io_cmds_highwater)" >> "${csv}"
}

# Detect controllers at startup
CONTROLLERS=$(detect_controllers)

if [ -z "${CONTROLLERS}" ]; then
    echo "No mpr controllers detected. Exiting."
    exit 1
fi

echo "Detected mpr controllers:${CONTROLLERS}"

# Initialise CSV files
for idx in ${CONTROLLERS}; do
    init_csv ${idx}
done

# Main collection loop
while true; do
    for idx in ${CONTROLLERS}; do
        collect ${idx}
    done
    sleep ${INTERVAL}
done
