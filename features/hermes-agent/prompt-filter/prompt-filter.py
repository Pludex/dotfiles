#!/usr/bin/env python3
import argparse
import json
import os
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SKIP_HEADERS = {"host", "content-length", "connection", "transfer-encoding", "accept-encoding"}
STRIPPED_FIELDS = ("tools", "tool_choice", "parallel_tool_calls")


def env(name, default=None):
    return os.environ.get(f"PROMPT_FILTER_{name}", default)


def parse_args():
    parser = argparse.ArgumentParser(
        description="OpenAI-compatible proxy that keeps only selected message roles."
    )
    parser.add_argument("--host", default=env("HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(env("PORT", "8081")))
    parser.add_argument("--upstream", default=env("UPSTREAM", "http://127.0.0.1:20128"))
    parser.add_argument(
        "--keep-roles",
        default=env("KEEP_ROLES", "user"),
        help="comma-separated message roles to keep",
    )
    parser.add_argument("--dump", default=env("DUMP"), help="append raw request bodies to this file")
    return parser.parse_args()


def make_handler(upstream, keep_roles, dump):
    class Handler(BaseHTTPRequestHandler):
        def _proxy(self):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else None

            if dump and body:
                with open(dump, "ab") as f:
                    f.write(body + b"\n")

            if body and self.path.split("?")[0].endswith("/chat/completions"):
                try:
                    data = json.loads(body)
                    data["messages"] = [
                        m for m in data.get("messages", []) if m.get("role") in keep_roles
                    ]
                    for field in STRIPPED_FIELDS:
                        data.pop(field, None)
                    body = json.dumps(data).encode()
                except ValueError:
                    pass

            req = urllib.request.Request(upstream + self.path, data=body, method=self.command)
            for key, value in self.headers.items():
                if key.lower() not in SKIP_HEADERS:
                    req.add_header(key, value)

            try:
                resp = urllib.request.urlopen(req, timeout=600)
            except urllib.error.HTTPError as err:
                resp = err

            self.send_response(resp.getcode())
            for key, value in resp.headers.items():
                if key.lower() not in SKIP_HEADERS:
                    self.send_header(key, value)
            self.send_header("Connection", "close")
            self.end_headers()

            while chunk := resp.read1(8192):
                self.wfile.write(chunk)
                self.wfile.flush()

        do_GET = do_POST = do_OPTIONS = _proxy

        def log_message(self, *args):
            pass

    return Handler


def main():
    args = parse_args()
    keep_roles = {r.strip() for r in args.keep_roles.split(",") if r.strip()}
    handler = make_handler(args.upstream.rstrip("/"), keep_roles, args.dump)
    server = ThreadingHTTPServer((args.host, args.port), handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
