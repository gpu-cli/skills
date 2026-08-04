#!/usr/bin/env node
// Proves that a cleanup changed comment text and nothing else.
//
// Usage: verify.mjs [--base <ref>] [--json] [<file>...]
//
// Strips every comment from both versions of each changed file and compares
// what is left. Equal means only comment text moved. Exit 1 on any difference.
//
// The stripper is quote-aware but still a heuristic, so this is a backstop
// against a slipped edit rather than a proof. Read a failure before dismissing
// it: in a language with unusual comment syntax it may be the check that is
// wrong, but assume it is the edit until you have looked.

import fs from 'node:fs';
import { execFileSync } from 'node:child_process';
import { syntaxFor, codeSkeleton } from './lib.mjs';

function parseArgs(argv) {
  const opts = { base: 'HEAD', json: false, files: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--base') opts.base = argv[++i];
    else if (a === '--json') opts.json = true;
    else if (a === '-h' || a === '--help') { usage(); process.exit(0); }
    else if (a.startsWith('-')) { console.error(`clean-comments: unknown option: ${a}`); process.exit(2); }
    else opts.files.push(a);
  }
  return opts;
}

function usage() {
  console.log(fs.readFileSync(new URL(import.meta.url), 'utf8')
    .split('\n').slice(2, 8).map((l) => l.replace(/^\/\/ ?/, '')).join('\n'));
}

const git = (args, opts = {}) => execFileSync('git', args, { encoding: 'utf8', ...opts });

function changedFiles(base) {
  return git(['diff', '--name-only', base]).split('\n').filter(Boolean);
}

function firstDifference(a, b) {
  const x = a.split('\n');
  const y = b.split('\n');
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    if (x[i] !== y[i]) {
      return { index: i + 1, before: x[i] ?? '(end of file)', after: y[i] ?? '(end of file)' };
    }
  }
  return null;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const files = opts.files.length ? opts.files : changedFiles(opts.base);
  const results = [];

  for (const file of files) {
    const syn = syntaxFor(file);
    if (!syn) continue;

    let before;
    try {
      before = git(['show', `${opts.base}:${file}`]);
    } catch {
      results.push({ file, status: 'added', detail: 'not in base; nothing to compare' });
      continue;
    }
    if (!fs.existsSync(file)) {
      results.push({ file, status: 'fail', detail: 'file was deleted; that is a code change' });
      continue;
    }

    const diff = firstDifference(codeSkeleton(before, syn), codeSkeleton(fs.readFileSync(file, 'utf8'), syn));
    results.push(diff
      ? { file, status: 'fail', detail: `code line ${diff.index} changed`, before: diff.before, after: diff.after }
      : { file, status: 'ok' });
  }

  const failed = results.filter((r) => r.status === 'fail');

  if (opts.json) {
    console.log(JSON.stringify({ ok: failed.length === 0, results }, null, 2));
  } else if (!results.length) {
    console.log('clean-comments: no comparable files changed.');
  } else if (!failed.length) {
    const checked = results.filter((r) => r.status === 'ok').length;
    const added = results.length - checked;
    console.log(`clean-comments: comment-only in ${checked} file(s)${added ? `, ${added} skipped as new` : ''}.`);
  } else {
    console.log(`clean-comments: CODE CHANGED in ${failed.length} file(s).\n`);
    for (const f of failed) {
      console.log(`  ${f.file}: ${f.detail}`);
      if (f.before !== undefined) {
        console.log(`    before: ${f.before.trim()}`);
        console.log(`    after:  ${f.after.trim()}`);
      }
    }
    console.log('\nRevert these files and redo the cleanup. Do not commit.');
  }

  process.exit(failed.length ? 1 : 0);
}

main();
