# mpr-monitor

Lightweight web dashboard for monitoring FreeBSD `mpr` and `mps` (Broadcom/LSI SAS HBA) driver DMA chain frame utilization.

Designed for production storage servers where chain frame exhaustion can cause I/O stalls and system freezes.

## What it monitors

For each detected `mpr` or `mps` controller (up to 6 per driver):

| Metric | Description |
|--------|-------------|
| `chain_free` | Chain frames available right now |
| `chain_free_lowwater` | Lowest chain_free has reached since boot |
| `chain_alloc_fail` | Failed chain frame allocations since boot (should be 0) |
| `io_cmds_active` | I/O commands in flight right now |
| `io_cmds_highwater` | Peak concurrent I/O commands since boot |

## Screenshot

The dashboard shows per-controller tabs with colour-coded health indicators, stat cards, and time-series charts for chain frame utilization, I/O activity, and allocation failures.

## Architecture

Three components, no external dependencies beyond Python 3.11:

- **Data collector** — shell script daemon sampling `sysctl` values every 60 seconds to per-controller CSV files in `/var/log/mpr_monitor/`
- **HTTP server** — minimal Python HTTP server on port 8080 serving the dashboard and CSV data
- **Dashboard** — single-file HTML page using Chart.js (loaded from CDN) with auto-detection of controllers and 30-second auto-reload

## Requirements

- FreeBSD (tested on 14.x)
- Python 3 (`pkg install python3`)
- One or more Broadcom/LSI SAS HBA controllers using the `mpr` or `mps` driver
- Network access to port 8080 (internal/firewalled networks — no authentication)

## Quick install

Clone the repository and run the install script as root:

```sh
git clone https://github.com/YOURUSERNAME/mpr-monitor.git
cd mpr-monitor
sh install.sh
```

Or as a one-liner (replace `YOURUSERNAME` with your GitHub username):

```sh
fetch -o - https://github.com/YOURUSERNAME/mpr-monitor/archive/refs/heads/main.tar.gz | tar xzf - && cd mpr-monitor-main && sh install.sh
```

The installer will:

1. Verify Python 3.11 is available
2. Verify at least one `mpr` or `mps` controller exists
3. Install application files to `/usr/local/share/mpr_monitor/`
4. Install rc.d service scripts to `/usr/local/etc/rc.d/`
5. Enable and start both services
6. Report the dashboard URL

Access the dashboard at `http://<server-ip>:8080`.

## Uninstall

```sh
cd mpr-monitor
sh install.sh uninstall
```

This will:

1. Stop both services
2. Remove `rc.conf` entries
3. Remove rc.d scripts
4. Remove application files
5. Remove log files
6. Optionally remove collected data (you will be prompted)

The system is fully reverted as if mpr-monitor was never installed.

## File layout

```
Installed files:

/usr/local/share/mpr_monitor/
    index.html                  Dashboard web page
    mpr_monitor_httpd.py        Python HTTP server
    mpr_collect.sh              Data collection script

/usr/local/etc/rc.d/
    mpr_monitor                 rc.d service: HTTP server
    mpr_collect                 rc.d service: data collector

/var/log/mpr_monitor/
    mpr0_stats.csv              CSV data for mpr controller 0
    mps0_stats.csv              CSV data for mps controller 0
    ...                         (one file per detected controller)

/var/log/
    mpr_monitor.log             HTTP server log
    mpr_collect.log             Data collector log
```

## Service management

```sh
# Check status
service mpr_collect status
service mpr_monitor status

# Restart
service mpr_monitor restart

# Stop
service mpr_collect stop
service mpr_monitor stop
```

## Background: why this exists

The `mpr` and `mps` drivers use DMA chain frames to map scatter/gather lists for I/O operations. Under heavy load (many drives, concurrent ZFS operations, Samba clients), the default allocation of 16384 chain frames can be exhausted. When this happens, the driver cannot submit new I/O, which stalls the system.

The fix is to increase `hw.mpr.max_chains` (or `hw.mps.max_chains`) in `/boot/loader.conf`, but you need visibility into actual utilization to choose the right value. This tool provides that visibility.

Key `loader.conf` tunables:

```
hw.mpr.max_chains=65536
hw.mps.max_chains=65536
```

This requires a reboot to take effect. Use this dashboard to monitor chain frame consumption under real workload and determine the appropriate value before and after the change.

## License

MIT
