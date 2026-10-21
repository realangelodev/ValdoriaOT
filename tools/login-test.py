#!/usr/bin/env python3
"""Logs in to the server the way a Tibia 10.98 client does, to check that everything works end to end.

  python3 tools/login-test.py ACCOUNT PASSWORD [HOST]

It asks the login server (port 7171) for the character list, then enters the game world (port 7172)
with the first character for a few seconds. Needs only Python 3 and the server's key.pem.
"""
import os
import re
import socket
import struct
import subprocess
import sys
import time
import zlib

VERSION = 1098
KEY_PEM = os.path.join(os.path.dirname(__file__), '..', 'server', 'key.pem')


def rsa_modulus():
    out = subprocess.run(['openssl', 'rsa', '-in', KEY_PEM, '-noout', '-modulus'], capture_output=True, text=True, check=True)
    return int(out.stdout.strip().split('=')[1], 16)


def rsa_block(payload, n):
    block = payload.ljust(128, b'\0')
    return pow(int.from_bytes(block, 'big'), 65537, n).to_bytes(128, 'big')


def tstring(s):
    data = s.encode('latin-1')
    return struct.pack('<H', len(data)) + data


def xtea_decrypt(data, key):
    out = bytearray()
    for i in range(0, len(data), 8):
        v0, v1 = struct.unpack_from('<II', data, i)
        delta, s = 0x9E3779B9, (0x9E3779B9 * 32) & 0xFFFFFFFF
        for _ in range(32):
            v1 = (v1 - ((((v0 << 4) ^ (v0 >> 5)) + v0) ^ (s + key[(s >> 11) & 3]))) & 0xFFFFFFFF
            s = (s - delta) & 0xFFFFFFFF
            v0 = (v0 - ((((v1 << 4) ^ (v1 >> 5)) + v1) ^ (s + key[s & 3]))) & 0xFFFFFFFF
        out += struct.pack('<II', v0, v1)
    return bytes(out)


def frame(body):
    return struct.pack('<H', len(body) + 4) + struct.pack('<I', zlib.adler32(body)) + body


def recv_packet(sock):
    head = sock.recv(2, socket.MSG_WAITALL)
    if len(head) < 2:
        raise ConnectionError('the server closed the connection')
    (size,) = struct.unpack('<H', head)
    return sock.recv(size, socket.MSG_WAITALL)[4:]  # drop the checksum


def read_string(buf, pos):
    (n,) = struct.unpack_from('<H', buf, pos)
    return buf[pos + 2:pos + 2 + n].decode('latin-1'), pos + 2 + n


def main():
    account, password = sys.argv[1], sys.argv[2]
    host = sys.argv[3] if len(sys.argv) > 3 else '127.0.0.1'
    n = rsa_modulus()
    key = [0x11111111, 0x22222222, 0x33333333, 0x44444444]
    key_bytes = struct.pack('<4I', *key)

    # Login server: account and password in, character list out.
    first = b'\0' + key_bytes + tstring(account) + tstring(password)
    token = b'\0' + tstring('') + b'\0'
    body = (b'\x01' + struct.pack('<HHI', 2, VERSION, VERSION) + b'\0' * 12 + b'\0'
            + rsa_block(first, n) + rsa_block(token, n))
    with socket.create_connection((host, 7171), timeout=10) as s:
        s.sendall(frame(body))
        reply = xtea_decrypt(recv_packet(s), key)
    (inner,) = struct.unpack_from('<H', reply, 0)
    msg, pos = reply[2:2 + inner], 0
    session, characters, world = None, [], None
    while pos < len(msg):
        op = msg[pos]
        pos += 1
        if op in (0x0A, 0x0B):
            text, pos = read_string(msg, pos)
            sys.exit(f'Login refused: {text}')
        elif op == 0x14:
            motd, pos = read_string(msg, pos)
            print('MOTD:', motd.split('\n', 1)[-1])
        elif op == 0x28:
            session, pos = read_string(msg, pos)
        elif op == 0x64:
            worlds = msg[pos]
            pos += 1
            for _ in range(worlds):
                pos += 1
                name, pos = read_string(msg, pos)
                ip, pos = read_string(msg, pos)
                (port,) = struct.unpack_from('<H', msg, pos)
                pos += 3
                world = (name, ip, port)
            count = msg[pos]
            pos += 1
            for _ in range(count):
                pos += 1
                name, pos = read_string(msg, pos)
                characters.append(name)
            break
    print(f'World: {world[0]} at {world[1]}:{world[2]}')
    print('Characters:', ', '.join(characters))
    if not characters:
        sys.exit('This account has no characters.')

    # Game server: answer the challenge, enter the world, stay a moment, leave.
    with socket.create_connection((host, world[2]), timeout=10) as s:
        challenge = recv_packet(s)
        timestamp, rnd = struct.unpack_from('<IB', challenge, 3)
        first = (b'\0' + key_bytes + b'\0' + tstring(session) + tstring(characters[0])
                 + struct.pack('<IB', timestamp, rnd))
        body = b'\x0a' + struct.pack('<HHIBH', 2, VERSION, VERSION, 0, 0) + rsa_block(first, n)
        s.sendall(frame(body))
        reply = xtea_decrypt(recv_packet(s), key)
        (inner,) = struct.unpack_from('<H', reply, 0)
        if reply[2] in (0x14, 0x16):
            text, _ = read_string(reply, 3)
            sys.exit(f'Game server refused: {text}')
        print(f'Entered the game world as {characters[0]} (first packet 0x{reply[2]:02X}, {inner} bytes).')
        time.sleep(3)
    print('OK')


if __name__ == '__main__':
    main()
