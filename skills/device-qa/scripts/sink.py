import http.server, socketserver, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "perf_sink.log"
PORT = 9009

class H(http.server.BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")

    def do_OPTIONS(self):
        self.send_response(204); self._cors(); self.end_headers()

    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode("utf-8", "replace")
        with open(OUT, "a") as f:
            f.write(body)
            if not body.endswith("\n"):
                f.write("\n")
        self.send_response(200); self._cors(); self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *a):
        pass

with socketserver.TCPServer(("127.0.0.1", PORT), H) as httpd:
    httpd.serve_forever()
