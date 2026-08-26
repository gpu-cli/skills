#!/usr/bin/env python3
"""Parse every shell snippet in the docs.

The docs are copy-paste targets: the CI recipe and the pre-push hook are pasted
whole, and neither is exercised by anything else. A snippet that does not parse
fails at the reader's shell, not here, so parse them all — including the shell
body inside the GitHub Actions `run: |` block, which is where a quoting slip
once survived precisely because it was not shell-fenced.

Placeholders like <ref> are documentation notation, not shell, and are
substituted before parsing. Usage: python3 check-doc-snippets.py  (exit 1 on any
failure).
"""
import re
import pathlib
import subprocess
import sys

SKILL_DIR = pathlib.Path(__file__).resolve().parent.parent


def snippets(doc):
    text = doc.read_text()
    found = [(m.start(), m.group(1))
             for m in re.finditer(r'```bash\n(.*?)```', text, re.S)]
    for m in re.finditer(r'```yaml\n(.*?)```', text, re.S):
        run = re.search(r'run: \|\n(.*?)(?=\n\S|\Z)', m.group(1), re.S)
        if not run:
            continue
        body = run.group(1)
        indent = min((len(l) - len(l.lstrip())
                      for l in body.splitlines() if l.strip()), default=0)
        found.append((m.start(), '\n'.join(l[indent:] for l in body.splitlines())))
    return found


def main():
    docs = sorted(SKILL_DIR.glob('references/*.md')) + [SKILL_DIR / 'SKILL.md']
    checked = failed = 0
    for doc in docs:
        for offset, snippet in snippets(doc):
            checked += 1
            line = doc.read_text()[:offset].count('\n') + 1
            probe = re.sub(r'<[a-z][a-z-]*>', 'PLACEHOLDER', snippet)
            result = subprocess.run(['bash', '-n'], input=probe,
                                    capture_output=True, text=True)
            if result.returncode:
                failed += 1
                rel = doc.relative_to(SKILL_DIR)
                print(f'  FAIL {rel}:{line} does not parse')
                for err in result.stderr.strip().splitlines():
                    print(f'       {err}')
    print(f'  {checked} doc snippet(s) parsed, {failed} failed')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
