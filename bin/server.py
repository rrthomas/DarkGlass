#!/usr/bin/env python3
# Development web server

import os
import sys
from pathlib import Path
import subprocess
import re
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib

from xdg import Mime

# Make a sanitized environment to keep perl -T happy
clean_env = dict(os.environ)
for var in ("PATH", "IFS", "CDPATH", "ENV", "BASH_ENV"):
    if clean_env.get(var):
        del clean_env[var]

script_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(script_dir)


# Parse web.pl
def get_config_variable(script, var_name):
    m = re.search(r"^\$DarkGlass::" + var_name + ' = "([^"]+)";', script, re.MULTILINE)
    if m:
        return m[1]


with open("web.pl") as h:
    script = h.read()
base_url = get_config_variable(script, "BaseUrl")
document_root = Path(os.path.expanduser(get_config_variable(script, "DocumentRoot")))
if not document_root.is_absolute():
    document_root = script_dir / document_root
document_root = document_root.resolve()

rendered_types = ["text/html", "text/markdown", "text/x-readme"]
index_pages = ["README.md", "index.html"]


class HTTPRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        filename = None
        url_path = urllib.parse.unquote(os.path.splitroot(self.path.removeprefix(base_url))[2]).removesuffix('/')
        input_path = os.path.join(document_root, url_path)
        if os.path.isdir(input_path):
            for i in index_pages:
                index_path = os.path.join(input_path, i)
                if os.path.exists(index_path):
                    filename = index_path
                    break
        elif os.path.isfile(input_path):
            filename = input_path
        elif input_path.endswith(".html"):
            # If a link ending '.html' is not found, guess a Markdown source file.
            md_filename = input_path.removesuffix(".html") + ".md"
            if os.path.exists(md_filename):
                filename = md_filename
        if filename is None:
            self.send_response(404)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(
                b"<html><head><title>No such page</title><body>No such page</body></html>"
            )
        else:
            mime_type = str(Mime.get_type2(filename).canonical())
            if mime_type in rendered_types:
                output_type = "text/html"
                output = subprocess.check_output(
                    [
                        os.path.join(".", "web.pl"),
                        os.path.relpath(filename, document_root),
                    ],
                    env=clean_env,
                )
            else:
                output_type = mime_type
                output = open(filename, "rb").read()
            self.send_response(200)
            self.send_header("Content-Type", output_type)
            self.end_headers()
            self.wfile.write(output)


httpd = HTTPServer(("localhost", 0), HTTPRequestHandler)
print(
    f"Connect to server at http://{str(httpd.server_address[0])}:{httpd.server_address[1]}{base_url}"
)
httpd.serve_forever()
