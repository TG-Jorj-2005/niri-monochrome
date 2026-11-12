#!/usr/bin/env python3
"""Minimal Niri IPC fixture with concurrent command and event-stream connections."""
import json
import os
import socket
import sys
import threading
import time

path = sys.argv[1]
if os.path.exists(path):
    os.unlink(path)
server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
server.bind(path)
server.listen(8)
server.settimeout(0.25)


def send(conn, value):
    conn.sendall((json.dumps(value) + "\n").encode())


def workspace(ident, idx, output, active, focused, window=None):
    return {"id": ident, "idx": idx, "name": None, "output": output,
            "is_urgent": False, "is_active": active, "is_focused": focused,
            "active_window_id": window}


def window(ident, workspace_id, focused):
    return {"id": ident, "title": "t" + str(ident), "app_id": "app" + str(ident),
            "pid": 1, "workspace_id": workspace_id, "is_focused": focused,
            "is_floating": False, "is_urgent": False, "layout": {},
            "future_field": 42}


def event_stream(conn, phase):
    try:
        send(conn, {"Ok": "Handled"})
        if phase == 1:
            send(conn, {"WorkspacesChanged": {"workspaces": [
                workspace(1, 1, "eDP-1", True, True, 7),
                workspace(2, 2, "eDP-1", False, False),
                workspace(3, 1, "HDMI-A-1", True, False)]}})
            send(conn, {"WindowsChanged": {"windows": [window(7, 1, True), window(9, 2, False)]}})
            send(conn, {"OverviewOpenedOrClosed": {"is_open": True}})
            send(conn, {"SomeFutureEvent": {"x": 1}})
            time.sleep(3.0)
            send(conn, {"WorkspaceActivated": {"id": 2, "focused": True}})
            send(conn, {"WindowFocusChanged": {"id": 9}})
            send(conn, {"WindowClosed": {"id": 7}})
            conn.sendall(b"this is not json\n")
            for bad in ({"WorkspacesChanged": {}}, {"WindowsChanged": {"windows": None}},
                        {"WindowOpenedOrChanged": {"window": None}}, {"WindowFocusChanged": {}}):
                send(conn, bad)
            time.sleep(2.0)
        else:
            send(conn, {"WorkspacesChanged": {"workspaces": [
                workspace(10, 1, "eDP-1", True, True)]}})
            send(conn, {"WindowsChanged": {"windows": []}})
            time.sleep(10.0)
    except (BrokenPipeError, ConnectionResetError, OSError):
        pass
    finally:
        conn.close()


phase = 0
threads = []
try:
    while phase < 2 or any(t.is_alive() for t in threads):
        try:
            conn, _ = server.accept()
        except socket.timeout:
            continue
        conn.settimeout(2)
        try:
            request = conn.makefile("rb").readline()
        except OSError:
            conn.close()
            continue
        if b'"EventStream"' in request:
            phase += 1
            thread = threading.Thread(target=event_stream, args=(conn, phase), daemon=True)
            thread.start()
            threads.append(thread)
        elif b'"Outputs"' in request:
            send(conn, {"Ok": {"Outputs": {}}})
            conn.close()
        else:
            send(conn, {"Err": "unsupported test request"})
            conn.close()
    for thread in threads:
        thread.join(timeout=12)
finally:
    server.close()
    if os.path.exists(path):
        os.unlink(path)
