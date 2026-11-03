"""Read-only checks against the deployed Pages site; never call app providers."""
import argparse
import json
import re
import time
from urllib.parse import urljoin
from urllib.request import urlopen

from release import ROOT, valid_manifest


def fetch(url):
    with urlopen(url, timeout=15) as response:
        return response.read(2000000)


def verify(url, commit):
    manifest = json.loads(fetch(urljoin(url, 'release-status.json')))
    if not valid_manifest(manifest) or manifest.get('commit') != commit:
        raise ValueError('Website points to another source release.')
    html = fetch(url).decode('utf-8')
    if '<title>Wayday' not in html:
        raise ValueError('Wayday page is unavailable.')
    scripts = re.findall(r'<script[^>]+src="([^"]+)"', html)
    styles = re.findall(r'<link[^>]+href="([^"]+\.css)"', html)
    if not scripts or not styles:
        raise ValueError('Built page assets are missing.')
    script = b''.join(fetch(urljoin(url, path)) for path in scripts).decode('utf-8')
    if manifest['apkUrl'] not in script or manifest['version'] not in script:
        raise ValueError('Download UI differs from published release metadata.')
    for path in styles:
        if not fetch(urljoin(url, path)):
            raise ValueError('Website stylesheet is empty.')
    if fetch(urljoin(url, 'assets/wayday-logo.png')) != (ROOT / 'apps/website/public/assets/wayday-logo.png').read_bytes():
        raise ValueError('Published website logo differs from the shared source.')
    checksum = fetch(manifest['apkUrl'] + '.sha256').decode().split()[0]
    if checksum != manifest['sha256']:
        raise ValueError('Published download checksum differs from website metadata.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--url', required=True)
    parser.add_argument('--commit', required=True)
    args = parser.parse_args()
    for attempt in range(4):
        try:
            verify(args.url, args.commit)
            break
        except (OSError, ValueError):
            if attempt == 3:
                raise
            time.sleep(5)
