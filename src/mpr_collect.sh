#!/bin/sh

# mpr-monitor data collector
# Detects all mpr and mps controllers and logs sysctl values to per-controller CSV files

DATA_DIR="/var/log/mpr_monitor"
INTERVAL=60

mkdir -p "${DATA_DIR}"

# Detect which mpr and mps controllers exist
detect_controllers() {
    controllers=""
    for drv in mpr mps; do
        for i in 0 1 2 3 4 5; do
            if sysctl -n dev.${drv}.${i}.chain_free > /dev/null 2>&1; then
                controllers="${controllers} ${drv}${i}"
            fi
        done
    done
    echo ${controllers}
}

# Write CSV header if file is new
init_csv() {
    local ctrl=$1
    local csv="${DATA_DIR}/${ctrl}_stats.csv"
    if [ ! -f "${csv}" ]; then
        echo "timestamp,chain_free,chain_free_lowwater,chain_alloc_fail,io_cmds_active,io_cmds_highwater" > "${csv}"
        chmod 644 "${csv}"
    fi
}

# Collect one sample for a controller
collect() {
    local ctrl=$1
    local drv=$(echo "${ctrl}" | sed 's/[0-9]*$//')
    local idx=$(echo "${ctrl}" | sed 's/^[a-z]*//')
    local csv="${DATA_DIR}/${ctrl}_stats.csv"
    echo "$(date +%Y-%m-%dT%H:%M:%S),$(sysctl -n dev.${drv}.${idx}.chain_free),$(sysctl -n dev.${drv}.${idx}.chain_free_lowwater),$(sysctl -n dev.${drv}.${idx}.chain_alloc_fail),$(sysctl -n dev.${drv}.${idx}.io_cmds_active),$(sysctl -n dev.${drv}.${idx}.io_cmds_highwater)" >> "${csv}"
}

# Detect controllers at startup
CONTROLLERS=$(detect_controllers)

if [ -z "${CONTROLLERS}" ]; then
    echo "No mpr or mps controllers detected. Exiting."
    exit 1
fi

echo "Detected controllers:${CONTROLLERS}"

# Initialise CSV files
for ctrl in ${CONTROLLERS}; do
    init_csv ${ctrl}
done

# Main collection loop
while true; do
    for ctrl in ${CONTROLLERS}; do
        collect ${ctrl}
    done
    sleep ${INTERVAL}
done
