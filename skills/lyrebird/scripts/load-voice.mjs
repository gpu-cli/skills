#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const VOICE_NAMES = ['VOICE.md', 'Voice.md', 'voice.md'];
const FALLBACK_DIRS = ['.agents/context', 'docs'];

export function resolveContextDir(cwd = process.cwd()) {
  const envDir = process.env.LYREBIRD_CONTEXT_DIR;
  if (envDir && envDir.trim()) {
    return path.isAbsolute(envDir.trim())
      ? envDir.trim()
      : path.resolve(cwd, envDir.trim());
  }

  if (firstExisting(cwd, VOICE_NAMES)) return cwd;

  for (const rel of FALLBACK_DIRS) {
    const candidate = path.resolve(cwd, rel);
    if (firstExisting(candidate, VOICE_NAMES)) return candidate;
  }

  return cwd;
}

export function loadVoice(cwd = process.cwd()) {
  const contextDir = resolveContextDir(cwd);
  const voicePath = firstExisting(contextDir, VOICE_NAMES);
  const voice = voicePath ? safeRead(voicePath) : null;

  return {
    hasVoice: !!voice && !isPlaceholderLike(voice),
    hasFile: !!voicePath,
    placeholderLike: !!voice && isPlaceholderLike(voice),
    voice,
    voicePath: voicePath ? path.relative(cwd, voicePath) : null,
    contextDir,
    utm: parseUtmConfig(voice),
  };
}

const UTM_PLATFORMS = ['blog', 'linkedin', 'reddit', 'x'];

// Parse the "Link Tracking (UTM)" section of VOICE.md into a structured config
// so write/modify can pass exact values to the validator instead of guessing.
// Returns { configured: false } when the section is absent.
export function parseUtmConfig(voiceText) {
  const empty = {
    configured: false,
    enabled: false,
    ownedDomains: [],
    source: {},
    medium: null,
    campaign: null,
    content: null,
    term: null,
    required: [],
  };
  if (!voiceText) return empty;

  const section = extractSection(voiceText, /link tracking|utm/i);
  if (section === null) return empty;

  const kv = parseSectionKeyValues(section);
  const get = (key) => (Object.prototype.hasOwnProperty.call(kv, key) ? kv[key] : null);

  const source = {};
  for (const platform of UTM_PLATFORMS) {
    const value = get(`utm_source_${platform}`);
    if (value) source[platform] = value;
  }

  const generic = get('utm_source');
  if (generic) {
    if (generic.includes('=')) {
      for (const pair of generic.split(',')) {
        const eq = pair.indexOf('=');
        if (eq === -1) continue;
        const key = pair.slice(0, eq).trim().toLowerCase();
        const token = pair.slice(eq + 1).trim();
        if (key && token && !source[key]) source[key] = token;
      }
    } else {
      for (const platform of UTM_PLATFORMS) {
        if (!source[platform]) source[platform] = generic.trim();
      }
    }
  }

  const enabledRaw = get('enabled');
  const enabled = enabledRaw === null ? true : /^(true|yes|on|1)$/i.test(enabledRaw);

  return {
    configured: true,
    enabled,
    ownedDomains: splitList(get('owned_domains') || get('owned_domain') || ''),
    source,
    medium: get('utm_medium'),
    campaign: get('utm_campaign'),
    content: get('utm_content'),
    term: get('utm_term'),
    required: splitList(get('required') || ''),
  };
}

function extractSection(text, headingRe) {
  const lines = text.split(/\r?\n/);
  let start = -1;
  let startLevel = 0;
  for (let i = 0; i < lines.length; i += 1) {
    const match = lines[i].match(/^(#{1,6})\s+(.*)$/);
    if (match && headingRe.test(match[2])) {
      start = i + 1;
      startLevel = match[1].length;
      break;
    }
  }
  if (start === -1) return null;

  const out = [];
  for (let i = start; i < lines.length; i += 1) {
    const heading = lines[i].match(/^(#{1,6})\s+/);
    if (heading && heading[1].length <= startLevel) break;
    out.push(lines[i]);
  }
  return out.join('\n');
}

function parseSectionKeyValues(section) {
  const kv = {};
  for (const rawLine of section.split(/\r?\n/)) {
    let line = rawLine.trim();
    if (!line || line.startsWith('```') || line.startsWith('#')) continue;
    line = line.replace(/^[-*]\s+/, '');
    line = line.replace(/^`+|`+$/g, '').trim();
    const match = line.match(/^([A-Za-z][A-Za-z0-9_]*)\s*:\s*(.*)$/);
    if (!match) continue;
    const key = match[1].toLowerCase();
    const value = match[2].trim().replace(/^["']|["']$/g, '').trim();
    if (!Object.prototype.hasOwnProperty.call(kv, key)) kv[key] = value;
  }
  return kv;
}

function splitList(value) {
  return String(value)
    .split(/[,\s]+/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function firstExisting(dir, names) {
  let entries;
  try {
    entries = fs.readdirSync(dir);
  } catch {
    return null;
  }

  for (const name of names) {
    const exact = entries.find((entry) => entry === name);
    if (exact) return path.join(dir, exact);
  }

  const lowerNames = new Set(names.map((name) => name.toLowerCase()));
  for (const entry of entries) {
    if (lowerNames.has(entry.toLowerCase())) {
      return path.join(dir, entry);
    }
  }

  return null;
}

function safeRead(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

function isPlaceholderLike(content) {
  const text = content.trim();
  if (text.length < 200) return true;
  const todoMatches = text.match(/\b(TODO|TBD|FIXME|\[.+?\])/gi) ?? [];
  return todoMatches.length >= 5;
}

function cli() {
  console.log(JSON.stringify(loadVoice(process.cwd()), null, 2));
}

// Compare realpaths so this still runs when invoked through a symlink
// (skills.sh symlinks .claude/skills/<name> -> .agents/skills/<name>, which
// makes process.argv[1] differ from the realpath-resolved import.meta.url).
function isMainModule() {
  const entry = process.argv[1];
  if (!entry) return false;
  try {
    return fs.realpathSync(entry) === fileURLToPath(import.meta.url);
  } catch {
    return false;
  }
}

if (isMainModule()) {
  cli();
}
