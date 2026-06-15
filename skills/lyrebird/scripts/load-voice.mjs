#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

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
  };
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

if (import.meta.url === `file://${process.argv[1]}`) {
  cli();
}
