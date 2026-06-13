#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';

const VALID_PLATFORMS = new Set(['blog', 'linkedin', 'reddit', 'x']);
const PLATFORM_FILES = {
  blog: 'blog.md',
  linkedin: 'linkedin.md',
  reddit: 'reddit.md',
  x: 'x.md',
};

function parseArgs(argv) {
  const args = {
    mode: null,
    dir: null,
    file: null,
    input: null,
    platform: null,
    platforms: null,
    xLimit: null,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    const key = arg.slice(2);
    const value = argv[i + 1];
    if (!value || value.startsWith('--')) {
      args[key] = true;
    } else {
      args[key] = value;
      i += 1;
    }
  }

  return args;
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const failures = validate(args);

  if (failures.length > 0) {
    console.error('Lyrebird validation failed:');
    for (const failure of failures) console.error(`- ${failure}`);
    process.exit(1);
  }

  console.log('Lyrebird validation passed.');
}

export function validate(args) {
  const failures = [];
  const mode = args.mode;

  if (mode !== 'write' && mode !== 'modify') {
    failures.push('Set --mode to write or modify.');
    return failures;
  }

  if (mode === 'write') {
    validateWrite(args, failures);
  } else {
    validateModify(args, failures);
  }

  return failures;
}

function validateWrite(args, failures) {
  if (!args.dir) {
    failures.push('Write mode requires --dir.');
    return;
  }

  const dir = path.resolve(args.dir);
  if (!fs.existsSync(dir) || !fs.statSync(dir).isDirectory()) {
    failures.push(`Output directory does not exist: ${args.dir}`);
    return;
  }

  const platforms = parsePlatforms(args.platforms || 'blog,linkedin,reddit,x', failures);
  for (const platform of platforms) {
    validatePlatformFile(path.join(dir, PLATFORM_FILES[platform]), platform, args, failures);
  }

  if (!hasImageArtifact(dir)) {
    failures.push('Write mode requires an image file or image metadata file in the output directory.');
  }
}

function validateModify(args, failures) {
  const platform = args.platform;
  if (!VALID_PLATFORMS.has(platform)) {
    failures.push('Modify mode requires --platform blog, linkedin, reddit, or x.');
    return;
  }

  if (!args.file) {
    failures.push('Modify mode requires --file.');
    return;
  }

  const filePath = path.resolve(args.file);
  validatePlatformFile(filePath, platform, args, failures);

  if (args.input) {
    const inputText = readIfExists(path.resolve(args.input));
    const outputText = readIfExists(filePath);
    if (outputText && hasImageMetadata(outputText) && !hasImageMetadata(inputText || '')) {
      failures.push('Modify mode added image metadata that was not present in the input.');
    }
  }
}

function parsePlatforms(raw, failures) {
  const platforms = raw.split(',').map((p) => p.trim().toLowerCase()).filter(Boolean);
  for (const platform of platforms) {
    if (!VALID_PLATFORMS.has(platform)) {
      failures.push(`Unknown platform: ${platform}`);
    }
  }
  return platforms.filter((platform) => VALID_PLATFORMS.has(platform));
}

function validatePlatformFile(filePath, platform, args, failures) {
  const text = readIfExists(filePath);
  if (text === null) {
    failures.push(`Missing ${platform} file: ${filePath}`);
    return;
  }

  if (!hasFrontmatter(text)) {
    failures.push(`${path.basename(filePath)} is missing YAML frontmatter.`);
  }

  if (!new RegExp(`platform:\\s*["']?${platform}["']?`, 'i').test(text)) {
    failures.push(`${path.basename(filePath)} frontmatter must include platform: ${platform}.`);
  }

  if (text.includes('\u2014')) {
    failures.push(`${path.basename(filePath)} contains an em dash.`);
  }

  if (/\bIn today's fast-paced world\b/i.test(text)) {
    failures.push(`${path.basename(filePath)} contains a banned generic opener.`);
  }

  if (platform === 'x') {
    validateXThread(text, args, failures);
  }
}

function validateXThread(text, args, failures) {
  const replies = [...text.matchAll(/^## Reply\s+\d+\s*$/gim)];
  if (replies.length === 0) {
    failures.push('x.md must mark each post with "## Reply N" headings.');
    return;
  }

  const limit = args.xLimit ? Number(args.xLimit) : null;
  if (limit && Number.isFinite(limit)) {
    const chunks = text.split(/^## Reply\s+\d+\s*$/gim).slice(1);
    chunks.forEach((chunk, index) => {
      const stripped = stripMarkdownMetadata(chunk).trim();
      if (stripped.length > limit) {
        failures.push(`X reply ${index + 1} exceeds --xLimit (${stripped.length}/${limit}).`);
      }
    });
  }
}

function hasFrontmatter(text) {
  return /^---\s*\n[\s\S]*?\n---\s*\n/.test(text);
}

function hasImageArtifact(dir) {
  const imageNames = ['image.md', 'image.json', 'image.yml', 'image.yaml'];
  const imageExts = new Set(['.jpg', '.jpeg', '.png', '.webp', '.avif']);
  for (const entry of fs.readdirSync(dir)) {
    if (imageNames.includes(entry.toLowerCase())) return true;
    if (imageExts.has(path.extname(entry).toLowerCase())) return true;
  }
  return false;
}

function hasImageMetadata(text) {
  return /^image:\s*["']?[^"'\n]+["']?\s*$/m.test(text);
}

function readIfExists(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

function stripMarkdownMetadata(text) {
  return text
    .replace(/^---\s*\n[\s\S]*?\n---\s*\n/, '')
    .replace(/\[[^\]]+\]\([^)]+\)/g, '')
    .replace(/[#*_`>~-]/g, '')
    .replace(/\s+/g, ' ');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
