#!/usr/bin/env python3

import json
import os
import signal
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MESSAGE = os.environ.get("APP_MESSAGE", "Hello from hello-service!")
START_TIME = time.time()


class Handler(BaseHTTPRequestHandler):
    server_version = "hello-service/1.0"
    sys_version = ""  

    def _send(self, code, body, content_type="text/plain; charset=utf-8"):
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(data)

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path == "/":
            self._send(200, MESSAGE + "\n")
        elif path == "/health":
            body = json.dumps(
                {"status": "ok", "uptime_seconds": int(time.time() - START_TIME)}
            )
            self._send(200, body + "\n", "application/json")
        else:
            self._send(404, "not found\n")

    do_HEAD = do_GET

    def log_message(self, fmt, *args):
        
        sys.stdout.write("%s %s\n" % (self.address_string(), fmt % args))
        sys.stdout.flush()


def make_server(port, host="0.0.0.0"):
    return ThreadingHTTPServer((host, port), Handler)


def main():
    port = int(os.environ.get("APP_PORT", "8080"))
    server = make_server(port)

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    print("hello-service listening on port %d" % port, flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
