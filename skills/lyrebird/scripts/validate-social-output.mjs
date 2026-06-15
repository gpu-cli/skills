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
const REQUIRED_METADATA = ['platform', 'title', 'description', 'audience', 'tags', 'sources', 'created'];
const WRITE_REQUIRED_METADATA = [...REQUIRED_METADATA, 'image'];
const MIN_BODY_CHARS = {
  blog: 300,
  linkedin: 120,
  reddit: 120,
};
const URL_RE = /https?:\/\/[^\s)]+/i;
const URL_GLOBAL_RE = /https?:\/\/[^\s<>"')\]]+/gi;
const ACCESS_DATE_RE = /\baccessed(?:\s+on)?\s*:?\s*["']?\d{4}-\d{2}-\d{2}["']?/i;
const MARKDOWN_LINK_RE = /\[[^\]]+\]\([^)]+\)/;
const PLACEHOLDER_RE = /\b(TBD|TODO|lorem ipsum|placeholder)\b|\[(?:text|insert[^\]\n]*|placeholder|todo|tbd)\]/i;
const IMAGE_URL_EXTENSION_RE = /\.(?:avif|gif|jpe?g|png|svg|webp)(?:[?#].*)?$/i;
const IMAGE_SOURCE_HOSTS = new Set([
  'cdn.lummi.ai',
  'cdn.pixabay.com',
  'images.ctfassets.net',
  'images.pexels.com',
  'images.unsplash.com',
  'lummi.ai',
  'pexels.com',
  'pixabay.com',
  'plus.unsplash.com',
  'res.cloudinary.com',
  'source.unsplash.com',
  'unsplash.com',
  'www.lummi.ai',
  'www.pexels.com',
  'www.pixabay.com',
  'www.unsplash.com',
]);
const EDITORIAL_BANS = [
  { label: 'double hyphen used as an em dash substitute', pattern: /--/ },
  { label: '"not only ... but also" filler', pattern: /\bnot only\b[\s\S]{0,120}\bbut also\b/i },
  { label: 'banned hype word', pattern: /\b(game-changing|revolutionary|supercharge|unlock)\b/i },
  { label: 'section-marker prose', pattern: /\b(let'?s dive in|the takeaway is clear)\b/i },
];

function parseArgs(argv) {
  const args = {
    mode: null,
    dir: null,
    file: null,
    input: null,
    platform: null,
    platforms: null,
    xLimit: null,
    'owned-domains': null,
    'utm-required': null,
    'utm-source': null,
    'utm-source-map': null,
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

  validateImageMetadata(dir, failures);
  if (!hasImageArtifact(dir)) {
    failures.push('Write mode requires image.md or an image file in the output directory.');
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

  const outputText = readIfExists(filePath);
  const outputImageReferences = outputText ? extractImageReferences(outputText) : [];
  if (outputImageReferences.length > 0) {
    if (!args.input) {
      failures.push('Modify mode output has an image reference; pass --input so preservation can be verified.');
    } else {
      const inputText = readIfExists(path.resolve(args.input));
      const inputImageReferences = new Set(extractImageReferences(inputText || ''));
      const added = outputImageReferences.filter((reference) => !inputImageReferences.has(reference));
      if (added.length > 0) {
        failures.push(`Modify mode added or changed image reference(s): ${added.join(', ')}.`);
      }
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

  const frontmatter = extractFrontmatter(text);
  let fields = {};
  if (!frontmatter) {
    failures.push(`${path.basename(filePath)} is missing YAML frontmatter.`);
  } else {
    fields = validateMetadata(frontmatter, platform, args.mode, path.basename(filePath), failures);
  }

  const body = stripFrontmatter(text);
  if (text.includes('\u2014')) {
    failures.push(`${path.basename(filePath)} contains an em dash.`);
  }

  if (/\bIn today's fast-paced world\b/i.test(body)) {
    failures.push(`${path.basename(filePath)} contains a banned generic opener.`);
  }

  validateEditorialBans(body, path.basename(filePath), failures);
  validateSourceEvidence(fields, body, path.basename(filePath), failures);
  validateUtmLinks(body, platform, args, path.basename(filePath), failures);

  if (platform === 'x') {
    validateXThread(text, args, failures);
  } else {
    validatePlatformBody(body, platform, args.mode, fields, frontmatter || '', path.basename(filePath), failures);
  }
}

function validateEditorialBans(body, fileName, failures) {
  for (const { label, pattern } of EDITORIAL_BANS) {
    if (pattern.test(body)) {
      failures.push(`${fileName} contains ${label}.`);
    }
  }
}

function validateXThread(text, args, failures) {
  const replies = [...text.matchAll(/^## Reply\s+\d+\s*$/gim)];
  if (replies.length === 0) {
    failures.push('x.md must mark each post with "## Reply N" headings.');
    return;
  }

  replies.forEach((reply, index) => {
    const number = Number(reply[0].match(/\d+/)?.[0]);
    if (number !== index + 1) {
      failures.push(`X reply headings must be sequential; expected Reply ${index + 1}.`);
    }
  });

  const limit = args.xLimit ? Number(args.xLimit) : 280;
  if (!Number.isFinite(limit) || limit <= 0) {
    failures.push('--xLimit must be a positive number when provided.');
    return;
  }

  const chunks = stripFrontmatter(text).split(/^## Reply\s+\d+\s*$/gim).slice(1);
  chunks.forEach((chunk, index) => {
    const replyText = stripSourcesSection(chunk).trim();
    if (PLACEHOLDER_RE.test(replyText)) {
      failures.push(`X reply ${index + 1} contains placeholder text.`);
    }
    if (MARKDOWN_LINK_RE.test(replyText)) {
      failures.push(`X reply ${index + 1} must use plain URLs, not Markdown links.`);
    }
    if (replyText.length < 15) {
      failures.push(`X reply ${index + 1} is empty or too thin to publish.`);
    }
    if (replyText.length > limit) {
      failures.push(`X reply ${index + 1} exceeds the X character limit (${replyText.length}/${limit}).`);
    }
  });
}

function validatePlatformBody(body, platform, mode, fields, frontmatter, fileName, failures) {
  const plain = stripMarkdownMetadata(body).trim();
  if (plain.length === 0) {
    failures.push(`${fileName} body must not be empty.`);
    return;
  }

  if (PLACEHOLDER_RE.test(body)) {
    failures.push(`${fileName} body contains placeholder text.`);
  }

  const minChars = MIN_BODY_CHARS[platform];
  if (minChars && plain.length < minChars) {
    failures.push(`${fileName} body is too thin for ${platform} (${plain.length}/${minChars} characters).`);
  }

  if ((platform === 'blog' || platform === 'linkedin') && paragraphCount(body) < 2) {
    failures.push(`${fileName} should contain at least two short paragraphs.`);
  }

  if (platform === 'reddit' && !/\b(subreddit|community|rules|r\/[A-Za-z0-9_]+)\b/i.test(`${frontmatter}\n${body}`)) {
    failures.push('reddit.md must include subreddit, community, or rules context in metadata or body.');
  }

  if (mode === 'modify' && platform === 'blog' && plain.length < 180) {
    failures.push('blog.md modify output is too thin to be a platform-native blog adaptation.');
  }
}

function validateSourceEvidence(fields, body, fileName, failures) {
  const metadataEntries = Array.isArray(fields.sources) ? fields.sources : [];
  const sectionEntries = extractSourcesSectionEntries(body);
  const allEntries = [...metadataEntries, ...sectionEntries];

  const invalidUrls = allEntries.flatMap((entry) => extractUrls(entry).filter((url) => !isEvidenceSourceUrl(url)));
  if (invalidUrls.length > 0) {
    failures.push(`${fileName} sources include image/CDN URL(s) that do not count as evidence: ${dedupe(invalidUrls).join(', ')}.`);
  }

  const entriesMissingAccessDate = allEntries.filter((entry) => {
    const evidenceUrls = extractUrls(entry).filter((url) => isEvidenceSourceUrl(url));
    return evidenceUrls.length > 0 && !ACCESS_DATE_RE.test(entry);
  });
  if (entriesMissingAccessDate.length > 0) {
    failures.push(`${fileName} source entries with evidence URLs must include accessed: YYYY-MM-DD.`);
  }

  const hasEvidenceSource = allEntries.some((entry) => {
    const evidenceUrls = extractUrls(entry).filter((url) => isEvidenceSourceUrl(url));
    return evidenceUrls.length > 0 && ACCESS_DATE_RE.test(entry);
  });
  if (!hasEvidenceSource) {
    failures.push(`${fileName} must include at least one evidence source URL with accessed: YYYY-MM-DD in frontmatter sources or a ## Sources section.`);
  }
}

function extractSourcesSectionEntries(body) {
  const bodyLines = body.split(/\r?\n/);
  const startIndex = bodyLines.findIndex((line) => /^## Sources\b/i.test(line));
  if (startIndex === -1) return [];

  const lines = [];
  for (let index = startIndex + 1; index < bodyLines.length; index += 1) {
    const line = bodyLines[index];
    if (/^##\s+\S/.test(line)) break;
    lines.push(line);
  }

  const entries = [];
  let current = '';
  for (const line of lines) {
    if (/^\s*(?:[-*]|\d+\.)\s+/.test(line)) {
      if (current.trim()) entries.push(current.trim());
      current = line.trim();
    } else if (current && line.trim()) {
      current = `${current} ${line.trim()}`;
    }
  }
  if (current.trim()) entries.push(current.trim());
  return entries;
}

function extractUrls(text) {
  return [...String(text).matchAll(URL_GLOBAL_RE)].map((match) => cleanUrl(match[0]));
}

function cleanUrl(url) {
  return url.replace(/[.,;:]+$/g, '');
}

function isEvidenceSourceUrl(rawUrl) {
  let parsed;
  try {
    parsed = new URL(rawUrl);
  } catch {
    return false;
  }

  const host = parsed.hostname.toLowerCase();
  const pathname = parsed.pathname.toLowerCase();
  if (IMAGE_SOURCE_HOSTS.has(host)) return false;
  if (/^(?:images?|img|media)\./.test(host)) return false;
  if (IMAGE_URL_EXTENSION_RE.test(pathname)) return false;
  return true;
}

function dedupe(values) {
  return [...new Set(values)];
}

// Opt-in: only runs when --owned-domains is passed. Checks that backlinks to the
// user's own destinations carry the required UTM params and the correct per-platform
// utm_source. Citation links (frontmatter sources and the ## Sources section) and
// third-party links are intentionally never tagged, so they are excluded.
function validateUtmLinks(body, platform, args, fileName, failures) {
  const ownedDomains = parseCsvArg(args['owned-domains']);
  if (ownedDomains.length === 0) return;

  const requiredArg = parseCsvArg(args['utm-required']);
  const required = requiredArg.length > 0 ? requiredArg : ['utm_source', 'utm_medium', 'utm_campaign'];
  const expectedSource = resolveExpectedUtmSource(platform, args);

  const scanned = stripSourcesSection(body);
  for (const rawUrl of dedupe(extractUrls(scanned))) {
    let parsed;
    try {
      parsed = new URL(rawUrl);
    } catch {
      continue;
    }
    if (!isOwnedHost(parsed.hostname, ownedDomains)) continue;

    const params = parsed.searchParams;
    const missing = required.filter((name) => !String(params.get(name) || '').trim());
    if (missing.length > 0) {
      failures.push(`${fileName} backlink to owned destination is missing ${missing.join(', ')}: ${rawUrl}`);
    }

    const actualSource = params.get('utm_source');
    if (expectedSource && actualSource && actualSource !== expectedSource) {
      failures.push(`${fileName} backlink utm_source must be "${expectedSource}" for ${platform}, found "${actualSource}": ${rawUrl}`);
    }
  }
}

function parseCsvArg(value) {
  if (!value || value === true) return [];
  return String(value).split(',').map((item) => item.trim()).filter(Boolean);
}

function resolveExpectedUtmSource(platform, args) {
  const map = parseUtmSourceMap(args['utm-source-map']);
  if (map[platform]) return map[platform];
  if (typeof args['utm-source'] === 'string' && args['utm-source'].trim()) {
    return args['utm-source'].trim();
  }
  return null;
}

function parseUtmSourceMap(value) {
  const map = {};
  for (const pair of parseCsvArg(value)) {
    const eq = pair.indexOf('=');
    if (eq === -1) continue;
    const key = pair.slice(0, eq).trim().toLowerCase();
    const token = pair.slice(eq + 1).trim();
    if (key && token) map[key] = token;
  }
  return map;
}

function isOwnedHost(hostname, ownedDomains) {
  const host = String(hostname).toLowerCase();
  return ownedDomains.some((domain) => {
    const normalized = domain
      .toLowerCase()
      .replace(/^https?:\/\//, '')
      .replace(/^\*?\.?/, '')
      .replace(/\/.*$/, '');
    return Boolean(normalized) && (host === normalized || host.endsWith(`.${normalized}`));
  });
}

function extractFrontmatter(text) {
  const match = text.match(/^---\s*\n([\s\S]*?)\n---\s*\n/);
  return match ? match[1] : null;
}

function validateMetadata(frontmatter, platform, mode, fileName, failures) {
  const { fields, errors } = parseFlatYaml(frontmatter);
  for (const error of errors) {
    failures.push(`${fileName} frontmatter has invalid YAML: ${error}`);
  }

  const required = mode === 'write' ? WRITE_REQUIRED_METADATA : REQUIRED_METADATA;

  for (const key of required) {
    if (!Object.prototype.hasOwnProperty.call(fields, key)) {
      failures.push(`${fileName} frontmatter is missing required field: ${key}.`);
    }
  }

  if (fields.platform !== platform) {
    failures.push(`${fileName} frontmatter must include platform: ${platform}.`);
  }

  validateMetadataTextField(fields, 'title', fileName, failures);
  validateMetadataTextField(fields, 'description', fileName, failures);
  validateMetadataTextField(fields, 'audience', fileName, failures);
  if (mode === 'write') {
    validateMetadataTextField(fields, 'image', fileName, failures, 'frontmatter image must not be empty in write mode');
  } else if (Object.prototype.hasOwnProperty.call(fields, 'image')) {
    validateMetadataTextField(fields, 'image', fileName, failures);
  }
  if (fields.tags !== undefined && !isYamlArrayish(fields.tags)) {
    failures.push(`${fileName} frontmatter tags must be a YAML array.`);
  }
  if (fields.sources !== undefined && !isYamlArrayish(fields.sources)) {
    failures.push(`${fileName} frontmatter sources must be a YAML array.`);
  }
  if (fields.created !== undefined && !/^\d{4}-\d{2}-\d{2}$/.test(fields.created)) {
    failures.push(`${fileName} frontmatter created must use YYYY-MM-DD.`);
  }

  return fields;
}

function validateMetadataTextField(fields, key, fileName, failures, emptyMessage = null) {
  if (!Object.prototype.hasOwnProperty.call(fields, key)) return;
  if (typeof fields[key] !== 'string') {
    failures.push(`${fileName} frontmatter ${key} must be a string.`);
    return;
  }

  const value = fields[key].trim();
  if (!value) {
    failures.push(`${fileName} ${emptyMessage || `frontmatter ${key} must not be empty`}.`);
  } else if (isPlaceholderValue(value)) {
    failures.push(`${fileName} frontmatter ${key} must not be placeholder text.`);
  }
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

function validateImageMetadata(dir, failures) {
  const imageMetadataPath = ['image.md', 'image.json', 'image.yml', 'image.yaml']
    .map((name) => path.join(dir, name))
    .find((candidate) => fs.existsSync(candidate));

  if (!imageMetadataPath) {
    failures.push('Write mode requires image metadata so source, license, and alt text are preserved.');
    return;
  }

  const text = readIfExists(imageMetadataPath) || '';
  const metadata = parseImageMetadata(text);
  const fileName = path.basename(imageMetadataPath);

  if (!metadata.source || !URL_RE.test(metadata.source)) {
    failures.push(`${fileName} is missing source URL.`);
  }

  if (!metadata.license) {
    failures.push(`${fileName} is missing license or usage terms.`);
  } else if (isVagueValue(metadata.license)) {
    failures.push(`${fileName} license or usage terms are too vague.`);
  } else if (!hasConcreteFreeUseTerms(metadata.license)) {
    failures.push(`${fileName} license or usage terms must name a free-to-use source/terms or include a terms URL.`);
  }

  if (!metadata.alt || isVagueValue(metadata.alt) || metadata.alt.length < 10) {
    failures.push(`${fileName} is missing useful alt text.`);
  }
}

function parseImageMetadata(text) {
  const metadata = {};
  const patterns = {
    source: /^(?:source|url):\s*(.+)$/im,
    license: /^(?:license|usage|terms):\s*(.+)$/im,
    alt: /^alt(?:_text|-text| text)?:\s*(.+)$/im,
  };

  for (const [key, pattern] of Object.entries(patterns)) {
    const match = text.match(pattern);
    if (match) metadata[key] = normalizeYamlScalar(match[1]);
  }

  return metadata;
}

function isVagueValue(value) {
  return /^(unknown|unclear|tbd|n\/a|na|none|todo|placeholder)$/i.test(value.trim());
}

function isPlaceholderValue(value) {
  return isVagueValue(value) || PLACEHOLDER_RE.test(value);
}

function hasConcreteFreeUseTerms(value) {
  return /\b(unsplash|pexels|lummi|creative commons|cc0|public domain|royalty-free|free to use|commercial use allowed|open license|permissive)\b/i.test(value);
}

function extractImageReferences(text) {
  const references = new Set();
  const frontmatter = extractFrontmatter(text);
  if (frontmatter) {
    const { fields } = parseFlatYaml(frontmatter);
    if (typeof fields.image === 'string' && fields.image.trim()) {
      references.add(normalizeImageReference(fields.image));
    }
  }

  const body = stripFrontmatter(text);
  for (const match of body.matchAll(/!\[[^\]]*]\(([^)]+)\)/g)) {
    references.add(normalizeImageReference(match[1]));
  }
  for (const match of body.matchAll(/<img\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/gi)) {
    references.add(normalizeImageReference(match[1]));
  }

  return [...references].filter(Boolean);
}

function normalizeImageReference(value) {
  return normalizeYamlScalar(value)
    .trim()
    .replace(/\s+["'][^"']+["']\s*$/, '')
    .replace(/^<(.+)>$/, '$1');
}

function parseFlatYaml(frontmatter) {
  const fields = {};
  const errors = [];
  const lines = frontmatter.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (/^\s*(#.*)?$/.test(line)) continue;
    if (/^\s+/.test(line)) {
      errors.push(`unexpected indented line ${index + 1}`);
      continue;
    }

    const match = line.match(/^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$/);
    if (!match) {
      errors.push(`line ${index + 1} is not a key/value pair`);
      continue;
    }

    const [, key, rawValue] = match;
    if (Object.prototype.hasOwnProperty.call(fields, key)) {
      errors.push(`duplicate key "${key}" on line ${index + 1}`);
      continue;
    }

    const parsed = parseYamlValue(rawValue, lines, index);
    if (parsed.error) errors.push(`line ${index + 1}: ${parsed.error}`);
    fields[key] = parsed.value;
    index = parsed.nextIndex;
  }
  return { fields, errors };
}

function parseYamlValue(value, lines, index) {
  const trimmed = value.trim();
  if (!trimmed) {
    const items = [];
    let cursor = index + 1;
    while (cursor < lines.length) {
      const itemMatch = lines[cursor].match(/^\s+-\s*(.*)$/);
      if (!itemMatch) break;
      let item = itemMatch[1].trim();
      cursor += 1;
      while (cursor < lines.length && /^\s{4,}\S/.test(lines[cursor]) && !/^\s+-\s*/.test(lines[cursor])) {
        item = `${item} ${lines[cursor].trim()}`.trim();
        cursor += 1;
      }
      items.push(normalizeYamlScalar(item));
    }
    if (items.length > 0) return { value: items, nextIndex: cursor - 1 };
    return { value: '', nextIndex: index };
  }

  if (trimmed.startsWith('[')) {
    if (!trimmed.endsWith(']')) {
      return { value: trimmed, nextIndex: index, error: 'inline array is missing closing bracket' };
    }
    return { value: parseInlineArray(trimmed), nextIndex: index };
  }

  return { value: normalizeYamlScalar(trimmed), nextIndex: index };
}

function normalizeYamlScalar(value) {
  const trimmed = value.trim();
  if ((trimmed.startsWith('"') && trimmed.endsWith('"')) || (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
    return trimmed.slice(1, -1);
  }
  return trimmed;
}

function isYamlArrayish(value) {
  return Array.isArray(value);
}

function parseInlineArray(value) {
  const content = value.slice(1, -1).trim();
  if (!content) return [];

  const items = [];
  let current = '';
  let quote = null;
  for (const char of content) {
    if ((char === '"' || char === "'") && quote === null) {
      quote = char;
      current += char;
      continue;
    }
    if (char === quote) {
      quote = null;
      current += char;
      continue;
    }
    if (char === ',' && quote === null) {
      items.push(normalizeYamlScalar(current));
      current = '';
      continue;
    }
    current += char;
  }
  if (current.trim()) items.push(normalizeYamlScalar(current));
  return items;
}

function readIfExists(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return null;
  }
}

function paragraphCount(text) {
  return text
    .split(/\n\s*\n/)
    .map((paragraph) => stripMarkdownMetadata(paragraph).trim())
    .filter((paragraph) => paragraph.length > 0).length;
}

function stripMarkdownMetadata(text) {
  return stripFrontmatter(text)
    .replace(/\[[^\]]+\]\([^)]+\)/g, '')
    .replace(/[#*_`>~-]/g, '')
    .replace(/\s+/g, ' ');
}

function stripFrontmatter(text) {
  return text.replace(/^---\s*\n[\s\S]*?\n---\s*\n/, '');
}

function stripSourcesSection(text) {
  return text.replace(/^## Sources\b[\s\S]*$/im, '');
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
