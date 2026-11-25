#!/usr/bin/env python3
"""Keep watching mDNS for the phone's Wireless debugging endpoint (_adb-tls-connect._tcp) and keep the
current "ip:port" in a file (removed again when the phone withdraws it).

Debian's adb has no mDNS support of its own, the port changes whenever Wireless debugging is toggled, and Android announces it
rather than reliably answering queries, so a long-running listener is needed: a one-shot scan usually finds nothing.

usage: discover.py <phone ip or ""> <output file>"""
import os
import sys
import time

from zeroconf import ServiceBrowser, ServiceListener, Zeroconf

TYPE = "_adb-tls-connect._tcp.local."
want_ip = sys.argv[1] if len(sys.argv) > 1 else ""
out = sys.argv[2] if len(sys.argv) > 2 else "/data/mdns_endpoint"
pending = []     # names to resolve (resolving inside the callback would block zeroconf's own thread)
removed = []
current = {}     # name -> "ip:port"


class Watch(ServiceListener):
    def add_service(self, zc, type_, name):
        pending.append(name)

    update_service = add_service

    def remove_service(self, zc, type_, name):
        removed.append(name)


def write():
    value = next(iter(current.values()), "")
    if value:
        tmp = out + ".tmp"
        with open(tmp, "w") as f:
            f.write(value + "\n")
        os.replace(tmp, out)
    elif os.path.exists(out):
        os.remove(out)


zc = Zeroconf()
ServiceBrowser(zc, TYPE, Watch())
while True:
    while removed:
        current.pop(removed.pop(), None)
        write()
    while pending:
        name = pending.pop(0)
        info = zc.get_service_info(TYPE, name, timeout=3000)
        if info is None:
            continue
        for addr in info.parsed_addresses():
            if ":" in addr:  # skip IPv6
                continue
            if not want_ip or addr == want_ip:
                current[name] = f"{addr}:{info.port}"
                write()
                break
    time.sleep(1)
