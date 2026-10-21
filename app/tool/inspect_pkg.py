#!/usr/bin/env python3
"""Prints a package's source (comments removed) as GitHub annotations, so the
API of a dependency can be read through the check-runs API without logs.
Usage: inspect_pkg.py <package> <relative-file>...   (max 9 files per run;
       a leading @ means relative to the package root, e.g. @CHANGELOG.md)
       inspect_pkg.py <package> --grep <regex>"""
import json, os, re, subprocess, sys

pkg = sys.argv[1]
cfg = json.load(open('.dart_tool/package_config.json'))
root = next(p['rootUri'] for p in cfg['packages'] if p['name'] == pkg)
base = os.path.normpath(os.path.join('.dart_tool', root.replace('file://', ''))) if not root.startswith('file://') else root[7:]
lib = os.path.join(base, 'lib')

def esc(s):
    return s.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')

def compact(text):
    out = []
    for line in text.splitlines():
        t = line.strip()
        if not t or t.startswith('//') or t.startswith('import ') or t.startswith('export '):
            continue
        out.append(line.rstrip())
    return '\n'.join(out)

if len(sys.argv) > 2 and sys.argv[2] == '--ls':
    listing = '\n'.join(sorted(os.path.relpath(os.path.join(d, f), lib) for d, _, fs in os.walk(lib) for f in fs))
    print('::notice title=ls %s::%s' % (pkg, esc(listing[:48000])))
elif len(sys.argv) > 3 and sys.argv[2] in ('--grep', '--grepc'):
    flags = ['-rnE'] + (['-A14'] if sys.argv[2] == '--grepc' else [])
    res = subprocess.run(['grep'] + flags + [sys.argv[3], lib], capture_output=True, text=True).stdout
    res = res.replace(lib + '/', '')
    print('::notice title=grep %s::%s' % (pkg, esc(res[:48000])))
else:
    for rel in sys.argv[2:]:
        path = os.path.join(base, rel[1:]) if rel.startswith('@') else os.path.join(lib, rel)
        try:
            text = compact(open(path).read())
        except OSError as e:
            text = 'cannot read: %s' % e
        print('::notice title=%s::%s' % (rel, esc(text[:48000])))
