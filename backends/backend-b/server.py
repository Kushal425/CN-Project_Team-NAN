from http.server import BaseHTTPRequestHandler, HTTPServer

HOST = "0.0.0.0"
PORT = 3002
BACKEND = "B"

class Handler(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path == "/api/status":
            body = f"Backend {BACKEND} is healthy\n".encode()

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "max-age=60")
            self.send_header("X-Backend", BACKEND)
            self.end_headers()
            self.wfile.write(body)

        else:
            body = f"Backend {BACKEND}\n".encode()

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("X-Backend", BACKEND)
            self.end_headers()
            self.wfile.write(body)

    def log_message(self, format, *args):
        print(f"[Backend {BACKEND}] {self.address_string()} - {format % args}")

server = HTTPServer((HOST, PORT), Handler)

print(f"Backend {BACKEND} listening on {HOST}:{PORT}")

server.serve_forever()
