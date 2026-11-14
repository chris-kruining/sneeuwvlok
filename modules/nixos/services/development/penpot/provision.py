"""Creates penpot accounts for zitadel's users, called by zitadel's sign in action.

Zitadel posts the user who is signing in, before it hands penpot their tokens. A user with one of the roles
that grant penpot gets an account, a user without one gets theirs deactivated. Penpot itself is driven through
its management socket (prepl), the same commands its own manage.py sends.
"""

import hmac
import json
import os
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LISTEN = ("127.0.0.1", int(os.environ["PROVISION_PORT"]))
PREPL = ("127.0.0.1", int(os.environ["PREPL_PORT"]))
ROLES = set(json.loads(os.environ["PROVISION_ROLES"]))

with open(os.path.join(os.environ["CREDENTIALS_DIRECTORY"], "secret"), encoding="utf-8") as f:
    SECRET = f.read().strip()


def prepl(cmd, **params):
    with socket.create_connection(PREPL, timeout=30) as s:
        f = s.makefile(mode="rw", encoding="utf-8")
        f.write(json.dumps({"cmd": cmd, "params": params}) + "\n")
        f.flush()

        while True:
            line = f.readline()
            if not line:
                raise RuntimeError("penpot closed the connection")

            message = json.loads(line)
            if message.get("tag") == "ret":
                if message.get("err"):
                    raise RuntimeError(message["err"].get("hint", "penpot refused the command"))
                return message.get("val")


def provision(user):
    email = user["email"].strip().lower()
    fullname = user.get("name") or email
    allowed = bool(ROLES & set(user.get("roles", [])))

    exists = any(p["email"] == email and not p.get("deletedAt") for p in prepl("search-profile", email=email) or [])

    if allowed and not exists:
        # Nobody signs in with a password, it only has to be one penpot accepts
        prepl("create-profile", email=email, fullname=fullname, password=os.urandom(32).hex(), isActive=True)
        return "created"

    if exists:
        prepl("update-profile", email=email, fullname=fullname, isActive=allowed)
        return "updated" if allowed else "deactivated"

    return "skipped"


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        token = self.headers.get("Authorization", "").removeprefix("Bearer ")
        if not hmac.compare_digest(token, SECRET):
            return self.reply(401, {"error": "unauthorized"})

        try:
            user = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
            result = provision(user)
        except Exception as cause:
            print(f"provisioning failed: {cause}", file=sys.stderr, flush=True)
            return self.reply(500, {"error": str(cause)})

        print(f"{user['email']}: {result}", flush=True)
        self.reply(200, {"result": result})

    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


ThreadingHTTPServer(LISTEN, Handler).serve_forever()
