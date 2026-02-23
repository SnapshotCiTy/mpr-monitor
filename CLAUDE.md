# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mpr-monitor is a FreeBSD monitoring dashboard for Broadcom/LSI SAS HBA (`mpr` driver) DMA chain frame utilization. It tracks chain frame exhaustion which can cause I/O stalls on production storage servers.

**Platform:** FreeBSD 14.x, Python 3 (stdlib only, no external dependencies).

## Architecture

Three independent components with no shared state except CSV files:

1. **Data Collector** (`src/mpr_collect.sh`) — Shell daemon that polls `sysctl dev.mpr.N.*` every 60 seconds and appends rows to per-controller CSV files in `/var/log/mpr_monitor/`.

2. **HTTP Server** (`src/mpr_monitor_httpd.py`) — Python stdlib `http.server` on port 8080. Three routes:
   - `GET /` → serves `index.html`
   - `GET /api/controllers` → JSON list of detected mpr controllers
   - `GET /data/mprN_stats.csv` → CSV data (N restricted to 0–5)

3. **Dashboard** (`src/index.html`) — Single-file SPA using Chart.js (CDN). Parses CSV client-side, renders charts, auto-reloads every 30/60/300s. Health indicators are color-coded by lowwater percentage (green >50%, yellow 15–50%, red <15% or any alloc failures).

Data flow: `sysctl → mpr_collect.sh → CSV files → mpr_monitor_httpd.py → index.html`

## Development Notes

- **No build system, no package manager, no tests, no linter.** This is a deployment-only project with ~1,200 lines total.
- **Installation:** `sh install.sh` (as root on FreeBSD). Installs to `/usr/local/share/mpr_monitor/` and creates rc.d services.
- **Uninstall:** `sh install.sh uninstall`
- **Service control:** `service mpr_collect start|stop|status` and `service mpr_monitor start|stop|status`
- The HTTP server runs as `nobody`; the collector runs as `root` (needs sysctl access).
- CSV format: `timestamp,chain_free,chain_free_lowwater,chain_alloc_fail,io_cmds_active,io_cmds_highwater`
- Frontend downsamples data beyond 500 points. Time axis format switches based on data timespan.
- rc.d scripts are in `src/rc.d/` and follow FreeBSD `rc.subr` conventions.
