"""Provision one authorized private debug installation without embedding its key.

The phone subsequently uses ordinary internet; ADB is only a one-time setup step.
No credentials are command arguments, build defines, logs, or tracked output.
"""
from pathlib import Path
import argparse
import json
import os
import re
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--package', default='dev.wayday.wayday')
    args = parser.parse_args()
    if not re.fullmatch(r'[A-Za-z0-9_.]+', args.package):
        raise ValueError('Invalid package')
    root = Path(__file__).resolve().parents[3]
    values = {}
    for line in (root / '.env.local').read_text(encoding='utf-8-sig').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            values[name.strip()] = value.strip().strip('\"\'')
    key = values.get('GEMINI_API_KEY', '')
    if not key or len(key) > 512 or any(c.isspace() for c in key):
        raise ValueError('GEMINI_API_KEY is missing or invalid in ignored .env.local')
    sdk = Path(os.environ.get('ANDROID_HOME', Path(os.environ['LOCALAPPDATA']) / 'Android/Sdk'))
    adb = sdk / 'platform-tools/adb.exe'
    command = [str(adb), '-s', args.device]

    def run(parts, **kwargs):
        return subprocess.run(command + parts, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=15, **kwargs)

    if run(['shell', 'run-as', args.package, 'id']).returncode:
        raise ValueError('Connect the selected device and install the private debug APK first')
    payload = json.dumps({'key': key}).encode('utf-8')
    if run(['shell', '-T', f"run-as {args.package} sh -c 'umask 077; cat > files/wayday-private-gemini.json'"], input=payload).returncode:
        raise ValueError('Private provisioning failed')
    try:
        if run(['shell', 'am', 'start', '-n', f'{args.package}/dev.wayday.wayday.MainActivity',
                '--ez', 'wayday_refresh_credential', 'true']).returncode:
            raise ValueError('Could not open Wayday for encrypted import')
        for _ in range(40):
            if run(['shell', f"run-as {args.package} sh -c 'test ! -e files/wayday-private-gemini.json && test -s no_backup/gemini-credential.json'"]).returncode == 0:
                print('Gemini credential imported into this private installation with Android Keystore encryption.')
                print('Gemini has no app-imposed request cap. No generation request was made by this setup.')
                return
            time.sleep(.25)
        raise ValueError('Encrypted import was not confirmed; the temporary provisioning file has been removed')
    finally:
        run(['shell', 'run-as', args.package, 'rm', '-f', 'files/wayday-private-gemini.json'])


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        # Do not print subprocess commands, environment values or response bodies.
        print(str(error) if isinstance(error, ValueError) else 'Private provisioning failed. Check the device connection.', file=sys.stderr)
        sys.exit(1)
