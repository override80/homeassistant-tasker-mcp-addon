#!/usr/bin/env python3
"""Find the phone's Wireless debugging endpoint (_adb-tls-connect._tcp) by mDNS: prints "ip:port" or nothing.
Debian's adb has no mDNS support of its own, and the port changes whenever Wireless debugging is toggled."""
import socket
import sys
import time

from zeroconf import ServiceBrowser, ServiceListener, Zeroconf

want_ip = sys.argv[1] if len(sys.argv) > 1 else ""
timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 8.0
found = []


class L(ServiceListener):
    def add_service(self, zc, type_, name):
        info = zc.get_service_info(type_, name, timeout=3000)
        if not info:
            return
        for addr in info.parsed_addresses():
            if ":" in addr:  # IPv6
                continue
            if not want_ip or addr == want_ip:
                found.append(f"{addr}:{info.port}")

    update_service = remove_service = add_service


zc = Zeroconf()
ServiceBrowser(zc, "_adb-tls-connect._tcp.local.", L())
end = time.time() + timeout
while time.time() < end and not found:
    time.sleep(0.2)
zc.close()
if found:
    print(found[0])
