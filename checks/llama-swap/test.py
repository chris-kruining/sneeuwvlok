import concurrent.futures
import http.server
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request


ready = threading.Event()
stream_started = threading.Event()
finish_stream = threading.Event()
received = []
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
wake_log = Path("wake.log")


class Backend(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        self.send_response(200 if ready.is_set() else 503)
        self.end_headers()
        self.wfile.write(b"{}")

    def do_POST(self):
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        received.append(request)
        self.send_response(200)
        if request.get("stream"):
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            self.wfile.write(b'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n')
            self.wfile.flush()
            stream_started.set()
            if not finish_stream.wait(10):
                raise TimeoutError("Test did not release the stream")
            self.wfile.write(b"data: [DONE]\n\n")
        else:
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"choices":[{"message":{"content":"Hello"}}]}')


def wait_for(predicate, timeout=8):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("Timed out waiting for test condition")


def wakes():
    return wake_log.read_text().splitlines() if wake_log.exists() else []


def get(path):
    with opener.open(base + path, timeout=3) as response:
        return json.load(response)


def infer(stream=False):
    request = urllib.request.Request(
        base + "/v1/chat/completions",
        data=json.dumps({
            "model": "test/model",
            "messages": [{"role": "user", "content": "Hello"}],
            "stream": stream,
        }).encode(),
        headers={"Content-Type": "application/json"},
    )
    return opener.open(request, timeout=25)


def complete():
    with infer() as response:
        return json.load(response)


backend = http.server.ThreadingHTTPServer(("127.0.0.1", 18081), Backend)
thread = threading.Thread(target=backend.serve_forever, daemon=True)
thread.start()
with socket.socket() as listener:
    listener.bind(("127.0.0.1", 0))
    port = listener.getsockname()[1]
base = f"http://127.0.0.1:{port}"

with open("proxy.log", "w") as log:
    proxy = subprocess.Popen(
        ["llama-swap", "-config", sys.argv[1], "-listen", f"127.0.0.1:{port}"],
        stdout=log,
        stderr=subprocess.STDOUT,
        env=dict(os.environ, WAKE_LOG=str(wake_log.absolute())),
    )
    try:
        def listening():
            if proxy.poll() is not None:
                raise AssertionError("llama-swap exited before becoming ready")
            try:
                return get("/v1/models")["data"]
            except urllib.error.URLError:
                return False

        wait_for(listening)
        assert get("/v1/models")["data"][0]["id"] == "test/model"
        assert not wakes(), "Listing models must not wake the host"
        print("PASS model discovery without wake", flush=True)

        ready.set()
        assert complete()["choices"][0]["message"]["content"] == "Hello"
        assert not wakes(), "An already healthy host must not receive WoL"
        wait_for(lambda: not get("/running")["running"])
        print("PASS warm request without wake and local idle cleanup", flush=True)

        ready.clear()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            pending = [pool.submit(complete) for _ in range(2)]
            wait_for(lambda: len(wakes()) == 1)
            time.sleep(0.5)
            assert not any(result.done() for result in pending)
            ready.set()
            for result in pending:
                assert result.result()["choices"][0]["message"]["content"] == "Hello"
        assert wakes() == ["-i 127.0.0.1 02:00:00:00:00:01"]
        assert all(request["model"] == "test/model" for request in received)
        print("PASS concurrent cold requests wait for health and share one wake", flush=True)

        with infer(stream=True) as response:
            assert response.readline().startswith(b"data:")
            assert stream_started.wait(3)
            time.sleep(2.5)
            assert get("/running")["running"], "Active streams must prevent idle cleanup"
            finish_stream.set()
            assert b"data: [DONE]" in response.read()
        wait_for(lambda: not get("/running")["running"])
        print("PASS unbuffered streaming survives local idle timeout", flush=True)

        ready.clear()
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(complete)
            wait_for(lambda: len(wakes()) == 2)
            ready.set()
            pending.result()
        wait_for(lambda: not get("/running")["running"])
        print("PASS wake check re-arms without stopping the remote backend", flush=True)

        ready.clear()
        try:
            complete()
        except urllib.error.HTTPError as error:
            assert error.code >= 500, error.code
        else:
            raise AssertionError("Unhealthy backend must fail after the wake timeout")
        print("PASS wake timeout returns an explicit server error", flush=True)
    except BaseException:
        log.flush()
        print(Path("proxy.log").read_text(), file=sys.stderr)
        raise
    finally:
        finish_stream.set()
        proxy.terminate()
        try:
            proxy.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proxy.kill()
            proxy.wait()
        backend.shutdown()
        backend.server_close()
        thread.join()
