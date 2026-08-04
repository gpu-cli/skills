// Comment tokenizer shared by scan.mjs and verify.mjs.
//
// Walks a file character by character, tracking string and block-comment state,
// and returns the comments plus the code with every comment removed. String
// state is the point: without it, `url = "https://x"` reads as a comment and a
// real code change can hide inside what looks like comment text.

import path from 'node:path';

const DQ = { q: '"', esc: true };
const SQ = { q: "'", esc: true };
const SQ_RAW = { q: "'", esc: false };
// Backtick strings span lines. Losing that would reset string state at each
// newline, and a `//` on a continuation line would open a fake comment that
// hides real edits from verify.
const BT = { q: '`', esc: true, multiline: true };
const BT_RAW = { q: '`', esc: false, multiline: true };

const C_LIKE = { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ] };
const HASH = { line: ['#'], block: [], strings: [DQ, SQ], lineNeedsBoundary: true };

const SYNTAX = {
  c: C_LIKE, cc: C_LIKE, cpp: C_LIKE, cxx: C_LIKE, h: C_LIKE, hpp: C_LIKE,
  hh: C_LIKE, cs: C_LIKE, java: C_LIKE, kt: C_LIKE, kts: C_LIKE, scala: C_LIKE,
  groovy: C_LIKE, swift: C_LIKE, m: C_LIKE, mm: C_LIKE, d: C_LIKE, zig: C_LIKE,
  php: C_LIKE, dart: C_LIKE, v: C_LIKE, proto: C_LIKE, tf: C_LIKE, hcl: C_LIKE,
  gradle: C_LIKE, styl: C_LIKE, less: C_LIKE, scss: C_LIKE, sass: C_LIKE,

  js: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  jsx: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  mjs: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  cjs: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  ts: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  tsx: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  mts: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  cts: { line: ['//'], block: [['/*', '*/']], strings: [DQ, SQ, BT] },
  vue: { line: ['//'], block: [['/*', '*/'], ['<!--', '-->']], strings: [DQ, SQ, BT] },
  svelte: { line: ['//'], block: [['/*', '*/'], ['<!--', '-->']], strings: [DQ, SQ, BT] },
  astro: { line: ['//'], block: [['/*', '*/'], ['<!--', '-->']], strings: [DQ, SQ, BT] },

  go: { line: ['//'], block: [['/*', '*/']], strings: [DQ, BT_RAW] },
  rs: { line: ['//'], block: [['/*', '*/']], strings: [DQ] },
  css: { line: [], block: [['/*', '*/']], strings: [DQ, SQ] },
  sql: { line: ['--'], block: [['/*', '*/']], strings: [DQ, SQ_RAW] },
  graphql: HASH, gql: HASH,

  py: {
    line: ['#'], block: [], strings: [DQ, SQ],
    triple: [['"""', '"""'], ["'''", "'''"]], lineNeedsBoundary: true,
  },
  pyi: {
    line: ['#'], block: [], strings: [DQ, SQ],
    triple: [['"""', '"""'], ["'''", "'''"]], lineNeedsBoundary: true,
  },
  rb: { line: ['#'], block: [['=begin', '=end']], strings: [DQ, SQ], lineNeedsBoundary: true },
  rake: { line: ['#'], block: [], strings: [DQ, SQ], lineNeedsBoundary: true },
  sh: { line: ['#'], block: [], strings: [DQ, SQ_RAW], lineNeedsBoundary: true },
  bash: { line: ['#'], block: [], strings: [DQ, SQ_RAW], lineNeedsBoundary: true },
  zsh: { line: ['#'], block: [], strings: [DQ, SQ_RAW], lineNeedsBoundary: true },
  fish: { line: ['#'], block: [], strings: [DQ, SQ_RAW], lineNeedsBoundary: true },
  ps1: { line: ['#'], block: [['<#', '#>']], strings: [DQ, SQ_RAW], lineNeedsBoundary: true },
  pl: HASH, pm: HASH, r: HASH, jl: HASH, ex: HASH, exs: HASH, cr: HASH,
  yml: HASH, yaml: HASH, toml: HASH, tfvars: HASH, cmake: HASH, mk: HASH,
  nim: { line: ['#'], block: [['#[', ']#']], strings: [DQ, SQ], lineNeedsBoundary: true },

  lua: { line: ['--'], block: [['--[[', ']]']], strings: [DQ, SQ] },
  hs: { line: ['--'], block: [['{-', '-}']], strings: [DQ] },
  clj: { line: [';'], block: [], strings: [DQ] },
  cljs: { line: [';'], block: [], strings: [DQ] },
  cljc: { line: [';'], block: [], strings: [DQ] },
  edn: { line: [';'], block: [], strings: [DQ] },
  erl: { line: ['%'], block: [], strings: [DQ], lineNeedsBoundary: true },
  hrl: { line: ['%'], block: [], strings: [DQ], lineNeedsBoundary: true },
  ml: { line: [], block: [['(*', '*)']], strings: [DQ] },
  mli: { line: [], block: [['(*', '*)']], strings: [DQ] },
  fs: { line: ['//'], block: [['(*', '*)']], strings: [DQ] },
  fsx: { line: ['//'], block: [['(*', '*)']], strings: [DQ] },
};

export function syntaxFor(file) {
  const ext = path.extname(file).slice(1).toLowerCase();
  return SYNTAX[ext] ?? null;
}

const at = (s, i, lit) => s.startsWith(lit, i);

// A `#` in `${x#y}` or `$#` is not a comment. Hash and percent comment markers
// only open a comment at the start of a line or after whitespace.
function boundaryOk(line, i) {
  return i === 0 || /\s/.test(line[i - 1]);
}

/**
 * Splits source into comments and comment-free code.
 * Returns { comments, codeLines } where codeLines[i] is line i with every
 * comment removed, preserving all other characters.
 */
export function tokenize(source, syn) {
  const lines = source.split('\n');
  const codeLines = [];
  const comments = [];
  let block = null; // { end, startLine, col, raw, kind }
  let str = null; // { q, esc }

  for (let ln = 0; ln < lines.length; ln++) {
    const line = lines[ln];
    let code = '';
    let i = 0;

    while (i < line.length) {
      if (block) {
        const e = line.indexOf(block.end, i);
        if (e === -1) {
          block.raw += line.slice(i) + '\n';
          i = line.length;
        } else {
          block.raw += line.slice(i, e + block.end.length);
          block.endLine = ln;
          comments.push(block);
          i = e + block.end.length;
          block = null;
        }
        continue;
      }

      if (str) {
        if (str.esc && line[i] === '\\') { code += line.slice(i, i + 2); i += 2; continue; }
        if (at(line, i, str.q)) { code += str.q; i += str.q.length; str = null; continue; }
        code += line[i++];
        continue;
      }

      let matched = false;

      for (const [open, close] of syn.triple ?? []) {
        if (!at(line, i, open)) continue;
        // A triple-quoted string is a docstring only as the first statement of a
        // module, class, or function. Anywhere else it is a value, and editing
        // it is a code change. A docstring starts its own line: any code before
        // the quote (`query = """`) makes it a value, whatever came above.
        const isDoc = line.slice(0, i).trim() === '' && looksLikeDocstring(lines, ln, i);
        if (isDoc) {
          block = { end: close, startLine: ln, col: i, raw: open, kind: 'doc' };
          i += open.length;
        } else {
          str = { q: close, esc: false, multiline: true };
          code += open;
          i += open.length;
        }
        matched = true;
        break;
      }
      if (matched) continue;

      for (const [open, close] of syn.block) {
        if (!at(line, i, open)) continue;
        block = {
          end: close, startLine: ln, col: i, raw: open,
          kind: open === '/*' && at(line, i, '/**') ? 'doc' : 'block',
        };
        i += open.length;
        matched = true;
        break;
      }
      if (matched) continue;

      for (const marker of syn.line) {
        if (!at(line, i, marker)) continue;
        if (syn.lineNeedsBoundary && !boundaryOk(line, i)) continue;
        comments.push({
          startLine: ln, endLine: ln, col: i, raw: line.slice(i), kind: 'line',
        });
        i = line.length;
        matched = true;
        break;
      }
      if (matched) continue;

      const s = syn.strings.find((d) => at(line, i, d.q));
      if (s) {
        str = { q: s.q, esc: s.esc, multiline: s.multiline };
        code += s.q;
        i += s.q.length;
        continue;
      }

      code += line[i++];
    }

    codeLines.push(code);
    if (str && !str.multiline) str = null; // an unterminated string ends at the newline
  }

  if (block) { block.endLine = lines.length - 1; comments.push(block); }
  return { comments, codeLines };
}

function looksLikeDocstring(lines, ln, col) {
  for (let k = ln - 1; k >= 0; k--) {
    const prev = lines[k].trim();
    if (!prev || prev.startsWith('#')) continue;
    return /:\s*$/.test(prev);
  }
  return col === 0; // start of file: a module docstring
}

/** Comment markers stripped, so detectors see prose. */
export function commentBody(c) {
  return c.raw
    .replace(/^\/\*+|\*+\/$/g, '')
    .replace(/^(<!--|-->)|-->$/g, '')
    .replace(/^("""|''')|("""|''')$/g, '')
    .replace(/^(=begin|=end)|^\(\*|\*\)$|^\{-|-\}$|^<#|#>$|^#\[|\]#$/g, '')
    .split('\n')
    .map((l) => l.replace(/^\s*(\/\/+!?|#+|--+|;+|%+|\*)\s?/, '').trim())
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Code with comments removed, blank lines dropped: two files agree here iff
 *  only comment text differs. */
export function codeSkeleton(source, syn) {
  return tokenize(source, syn).codeLines
    .map((l) => l.replace(/\s+$/, ''))
    .filter((l) => l.trim() !== '')
    .join('\n');
}
