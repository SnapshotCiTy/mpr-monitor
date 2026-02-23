#!/usr/local/bin/python3
"""
mpr-monitor HTTP server.
Serves the dashboard and per-controller CSV data files.

Listens on 0.0.0.0:8080
  GET /                -> index.html
  GET /api/controllers -> JSON list of detected controllers
  GET /data/mprN.csv   -> CSV data for controller N
"""

import http.server
import json
import os
import re
import sys

LISTEN_ADDR = '0.0.0.0'
LISTEN_PORT = 8080
HTML_DIR = '/usr/local/share/mpr_monitor'
DATA_DIR = '/var/log/mpr_monitor'


class MPRHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        path = self.path.split('?')[0]

        if path == '/' or path == '/index.html':
            self.serve_file(os.path.join(HTML_DIR, 'index.html'), 'text/html')

        elif path == '/api/controllers':
            self.serve_controllers()

        elif path.startswith('/data/') and path.endswith('.csv'):
            filename = os.path.basename(path)
            # Only allow mprN_stats.csv pattern
            if re.match(r'^mpr[0-5]_stats\.csv$', filename):
                self.serve_file(os.path.join(DATA_DIR, filename), 'text/csv')
            else:
                self.send_error(404)
        else:
            self.send_error(404)

    def serve_controllers(self):
        """Return JSON list of controllers that have CSV data files."""
        controllers = []
        for i in range(6):
            csv_path = os.path.join(DATA_DIR, f'mpr{i}_stats.csv')
            if os.path.exists(csv_path) and os.path.getsize(csv_path) > 0:
                # Read first data line to check there's actual data
                controllers.append({
                    'id': i,
                    'name': f'mpr{i}',
                    'csv': f'/data/mpr{i}_stats.csv'
                })

        content = json.dumps(controllers).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', len(content))
        self.send_header('Cache-Control', 'no-cache')
        self.end_headers()
        self.wfile.write(content)

    def serve_file(self, filepath, content_type):
        try:
            with open(filepath, 'rb') as f:
                content = f.read()
            self.send_response(200)
            self.send_header('Content-Type', content_type + '; charset=utf-8')
            self.send_header('Content-Length', len(content))
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(content)
        except FileNotFoundError:
            self.send_error(404, f'File not found: {filepath}')

    def log_message(self, format, *args):
        if '404' in str(args) or '500' in str(args):
            super().log_message(format, *args)


def main():
    server = http.server.HTTPServer((LISTEN_ADDR, LISTEN_PORT), MPRHandler)
    print(f'mpr-monitor serving on http://{LISTEN_ADDR}:{LISTEN_PORT}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nShutting down.')
        server.shutdown()


if __name__ == '__main__':
    main()
