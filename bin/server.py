#!/usr/bin/python
# Development web server

import os
from pathlib import Path
import subprocess
from http.server import HTTPServer, BaseHTTPRequestHandler

# Make a sanitized environment to keep perl -T happy
clean_env = dict(os.environ)
for var in ("PATH", "IFS", "CDPATH", "ENV", "BASH_ENV"):
    if clean_env.get(var):
        del clean_env[var]

script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)

class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        output = subprocess.check_output(
            [
                os.path.join(".", "web.pl"),
                self.path,
            ],
            env=clean_env,
        )
        self.wfile.write(output)

httpd = HTTPServer(('localhost', 0), SimpleHTTPRequestHandler)
print(f"Connect to server at http://{httpd.server_address[0]}:{httpd.server_address[1]}")
httpd.serve_forever()
