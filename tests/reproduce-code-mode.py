#!/usr/bin/env python3
"""Exercise the published code-mode host's framed IPC and actual V8 execution."""
import json
import os
import queue
import struct
import subprocess
import sys
import threading
import time

label, *command = sys.argv[1:]
messages = queue.Queue()
callback_inputs = []
callback_nonce = os.urandom(16).hex()

with open(f"{label}-stderr.log", "wb") as errors:
    os.dup2(errors.fileno(), 555)
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, pass_fds=(555,))
    os.close(555)

    def read_stderr():
        while data := process.stderr.read1(4096):
            errors.write(data)
            errors.flush()

    def read_exact(size):
        data = b""
        while len(data) < size:
            chunk = process.stdout.read(size - len(data))
            if not chunk:
                raise EOFError(f"host EOF after {len(data)} of {size} bytes")
            data += chunk
        return data

    def read_frames():
        try:
            while True:
                size = struct.unpack("<I", read_exact(4))[0]
                if size > 64 * 1024 * 1024:
                    raise ValueError(f"invalid frame size: {size}")
                message = json.loads(read_exact(size))
                print(f"{label}: {json.dumps(message)}", flush=True)
                messages.put(message)
        except Exception as error:
            messages.put(error)

    threading.Thread(target=read_stderr, daemon=True).start()
    threading.Thread(target=read_frames, daemon=True).start()

    def send(message):
        data = json.dumps(message).encode()
        process.stdin.write(struct.pack("<I", len(data)) + data)
        process.stdin.flush()

    def receive(request_id=None, seconds=120):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            message = messages.get(timeout=max(0.01, end - time.monotonic()))
            if isinstance(message, Exception):
                raise RuntimeError(f"{label}: {message}; process status={process.poll()}")
            if request_id is None:
                return message
            if message.get("type") == "delegate/request":
                invocation = message["request"]["invocation"]
                assert invocation["tool_name"]["name"] == "echo", invocation
                assert invocation["input"] == {"value": "ish-callback-ok"}, invocation
                callback_inputs.append(invocation["input"])
                send({"type": "delegate/response", "id": message["id"],
                      "result": {"status": "ok", "value": {"type": "tool/result",
                                 "result": {"nonce": callback_nonce}}}})
                continue
            if message.get("id") == request_id:
                result = message["result"]
                if result["status"] != "ok":
                    raise RuntimeError(result)
                if result["value"].get("type") == "execution/started":
                    continue
                return result["value"]
        raise TimeoutError(f"{label}: response {request_id} timed out")

    def request(request_id, body):
        send({"type": "operation/request", "id": request_id, "request": body})
        return receive(request_id)

    try:
        send({"type": "connection/hello", "supportedVersions": [1],
              "requiredCapabilities": [], "optionalCapabilities": []})
        hello = receive()
        assert hello["type"] == "connection/ready", hello
        assert hello["selectedVersion"] == 1, hello
        print(f"PASS: {label}: code-mode host handshake", flush=True)
        session = "ish-code-mode-probe"
        opened = request(1, {"method": "session/open", "sessionId": session})
        assert opened["type"] == "session/ready", opened
        result = request(2, {"method": "session/execute", "sessionId": session,
                            "request": {"tool_call_id": "ish-probe", "enabled_tools": [],
                                        "source": "text('ish-code-mode-ok');",
                                        "yield_time_ms": 1000, "max_output_tokens": 100}})
        # A slow JIT may yield before finishing; wait for that same cell.
        for request_id in range(3, 13):
            if "Yielded" not in result:
                break
            yielded = result["Yielded"]
            waited = request(request_id, {"method": "session/wait", "sessionId": session,
                                         "request": {"cell_id": yielded["cell_id"],
                                                     "yield_time_ms": 1000}})
            result = next(iter(waited["outcome"].values()))
        assert "Result" in result, result
        assert result["Result"]["error_text"] is None, result
        assert "ish-code-mode-ok" in json.dumps(result), result
        print(f"PASS: {label}: actual V8 JavaScript output", flush=True)
        callback = request(15, {"method": "session/execute", "sessionId": session,
                               "request": {"tool_call_id": "ish-callback-probe",
                                           "enabled_tools": [{"name": "echo",
                                               "tool_name": {"name": "echo", "namespace": None},
                                               "description": "Return a unique probe nonce",
                                               "kind": "function", "input_schema": None,
                                               "output_schema": None}],
                                           "source": "text((await tools.echo({value:'ish-callback-ok'})).nonce);",
                                           "yield_time_ms": 1000, "max_output_tokens": 100}})
        for request_id in range(16, 20):
            if "Yielded" not in callback:
                break
            waited = request(request_id, {"method": "session/wait", "sessionId": session,
                                         "request": {"cell_id": callback["Yielded"]["cell_id"],
                                                     "yield_time_ms": 1000}})
            callback = next(iter(waited["outcome"].values()))
        assert callback_inputs == [{"value": "ish-callback-ok"}], callback_inputs
        assert callback["Result"]["error_text"] is None, callback
        assert callback_nonce in json.dumps(callback), callback
        print(f"PASS: {label}: V8 awaited real IPC tool callback and returned nonce", flush=True)
        closed = request(20, {"method": "session/shutdown", "sessionId": session})
        assert closed["type"] == "session/closed", closed
        process.stdin.close()
        assert process.wait(timeout=15) == 0
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
