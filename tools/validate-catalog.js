#!/usr/bin/env node
/**
 * Validation suite for resources-generative-ai repository.
 * Validates Agent Skills specification compliance, subagent configurations,
 * tools completeness, multi-language catalog synchronization, SHA256 checksums,
 * directory traversal protection, and secret/DLP leakage prevention.
 */

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const REPO_ROOT = path.resolve(__dirname, '..');
const CATALOG_EN_PATH = path.join(REPO_ROOT, 'catalog.json');
const CATALOG_PT_PATH = path.join(REPO_ROOT, 'catalog.pt-BR.json');
const STABLE_SKILLS_DIR = path.join(REPO_ROOT, 'stable', 'skills');
const STABLE_AGENTS_DIR = path.join(REPO_ROOT, 'stable', 'agents');
const TOOLS_DIR = path.join(REPO_ROOT, 'tools');

const KEBAB_CASE_RE = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

// Generic Secret & Sensitive Data Patterns (no personal names hardcoded)
const GENERIC_DLP_PATTERNS = [
  { name: 'Private Key Header', regex: /-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/ },
  { name: 'Generic Cloud API Key / Token', regex: /\b(?:ghp_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9_]{82}|xox[baprs]-[0-9a-zA-Z]{10,48}|AKIA[0-9A-Z]{16})\b/ },
  { name: 'Hardcoded Machine User Path', regex: /(?:[a-zA-Z]:[\\/](?:Users|home)[\\/](?!runner\b|<|[a-zA-Z0-9._-]+<)[a-zA-Z0-9._-]+|[\\/](?:home|Users)[\\/](?!runner\b|<|[a-zA-Z0-9._-]+<)[a-zA-Z0-9._-]+|(?:^|[\s"'`\\/])Users\\[a-zA-Z0-9._-]+)/i },
];

// Optional custom DLP terms supplied via environment variable (e.g., in private CI or local runs)
const CUSTOM_DLP_TERMS = (process.env.CUSTOM_DLP_TERMS || '')
  .split(',')
  .map(s => s.trim().toLowerCase())
  .filter(Boolean);

let errors = 0;
let warnings = 0;

function logError(msg) {
  console.error(`  [ERROR] ${msg}`);
  errors++;
}

function logWarn(msg) {
  console.warn(`  [WARN]  ${msg}`);
  warnings++;
}

function logOk(msg) {
  console.log(`  [OK]    ${msg}`);
}

function sha256File(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(content).digest('hex');
}

function hasCustomRestrictedTerm(text) {
  if (!text || CUSTOM_DLP_TERMS.length === 0) return false;
  const lower = text.toLowerCase();
  for (const term of CUSTOM_DLP_TERMS) {
    if (lower.includes(term)) {
      return true;
    }
  }
  return false;
}

/**
 * Strict YAML frontmatter parser for skills and agent manifests.
 * Enforces indentation, quoted metadata strings, quote matching, and YAML syntax.
 */
function parseYamlFrontmatter(content, filePath) {
  if (!content.startsWith('---\n') && !content.startsWith('---\r\n')) {
    logError(`${filePath}: File must start strictly with opening frontmatter delimiter (---) on line 1`);
    return null;
  }

  // Find closing delimiter strictly on its own line: \n---\n or \n---\r\n
  const endMatch = content.match(/\r?\n---\r?(?:\n|$)/);
  if (!endMatch) {
    logError(`${filePath}: Malformed YAML frontmatter: missing closing delimiter (---) on separate line`);
    return null;
  }

  const frontmatterEndIndex = endMatch.index;
  const openingEndIndex = content.indexOf('\n') + 1;
  const rawYaml = content.slice(openingEndIndex, frontmatterEndIndex);

  const lines = rawYaml.split(/\r?\n/);
  const result = { metadata: {} };
  const rootKeys = new Set();
  const metadataKeys = new Set();
  let inMetadata = false;
  let hasSyntaxError = false;

  for (let i = 0; i < lines.length; i++) {
    const lineNum = i + 2; // Line 1 is opening ---
    const line = lines[i];
    const trimmed = line.trim();

    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    if (line.includes('\t')) {
      logError(`${filePath}:${lineNum}: Illegal tab character found in YAML frontmatter`);
      hasSyntaxError = true;
      continue;
    }

    // Check indentation
    const indentMatch = line.match(/^(\s*)/);
    const indentLength = indentMatch ? indentMatch[1].length : 0;

    if (inMetadata) {
      if (indentLength === 2) {
        const colonIdx = trimmed.indexOf(':');
        if (colonIdx === -1) {
          logError(`${filePath}:${lineNum}: Invalid syntax in metadata: missing colon in "${trimmed}"`);
          hasSyntaxError = true;
          continue;
        }

        const key = trimmed.slice(0, colonIdx).trim();
        const rawVal = trimmed.slice(colonIdx + 1);

        if (!/^[a-zA-Z0-9_-]+$/.test(key)) {
          logError(`${filePath}:${lineNum}: Invalid metadata key name "${key}"`);
          hasSyntaxError = true;
          continue;
        }

        if (metadataKeys.has(key)) {
          logError(`${filePath}:${lineNum}: Duplicate metadata key "${key}"`);
          hasSyntaxError = true;
          continue;
        }
        metadataKeys.add(key);

        if (!rawVal.startsWith(' ') && rawVal.length > 0) {
          logError(`${filePath}:${lineNum}: Invalid YAML key-value syntax: missing space after colon in "${trimmed}"`);
          hasSyntaxError = true;
          continue;
        }

        const val = rawVal.trim();
        if (!val) {
          logError(`${filePath}:${lineNum}: Empty value for metadata key "${key}"`);
          hasSyntaxError = true;
          continue;
        }

        // Validate quotes and value
        const isDoubleQuoted = /^"(?:[^"\\]|\\.)*"$/.test(val);
        const isSingleQuoted = /^'[^']*'$/.test(val);

        if (val.startsWith('"')) {
          if (!isDoubleQuoted) {
            logError(`${filePath}:${lineNum}: Unclosed or invalid double-quote in metadata value: "${trimmed}"`);
            hasSyntaxError = true;
            continue;
          }
        } else if (val.startsWith("'")) {
          if (!isSingleQuoted) {
            logError(`${filePath}:${lineNum}: Unclosed or invalid single-quote in metadata value: "${trimmed}"`);
            hasSyntaxError = true;
            continue;
          }
        } else {
          // Agent Skills specification: metadata values must be string types
          if (val === 'true' || val === 'false' || !isNaN(Number(val))) {
            logError(`${filePath}:${lineNum}: Agent Skills spec requires metadata values to be quoted strings (found scalar "${val}")`);
            hasSyntaxError = true;
            continue;
          }
          if (val.includes(': ')) {
            logError(`${filePath}:${lineNum}: Unquoted string contains colon followed by space: "${trimmed}"`);
            hasSyntaxError = true;
            continue;
          }
        }

        result.metadata[key] = isDoubleQuoted || isSingleQuoted ? val.slice(1, -1) : val;
        continue;
      } else if (indentLength > 0) {
        logError(`${filePath}:${lineNum}: Invalid indentation in metadata (expected 2 spaces, found ${indentLength})`);
        hasSyntaxError = true;
        continue;
      } else {
        inMetadata = false;
      }
    }

    if (indentLength !== 0) {
      logError(`${filePath}:${lineNum}: Unexpected indentation at root level: "${line}"`);
      hasSyntaxError = true;
      continue;
    }

    const colonIdx = trimmed.indexOf(':');
    if (colonIdx === -1) {
      logError(`${filePath}:${lineNum}: Invalid YAML statement (missing colon): "${trimmed}"`);
      hasSyntaxError = true;
      continue;
    }

    const key = trimmed.slice(0, colonIdx).trim();
    const rawVal = trimmed.slice(colonIdx + 1);

    if (!/^[a-zA-Z0-9_-]+$/.test(key)) {
      logError(`${filePath}:${lineNum}: Invalid YAML key identifier "${key}"`);
      hasSyntaxError = true;
      continue;
    }

    if (rootKeys.has(key)) {
      logError(`${filePath}:${lineNum}: Duplicate YAML key "${key}"`);
      hasSyntaxError = true;
      continue;
    }
    rootKeys.add(key);

    if (key === 'metadata') {
      if (rawVal.trim().length > 0) {
        logError(`${filePath}:${lineNum}: Invalid metadata declaration (expected newline before mapping)`);
        hasSyntaxError = true;
      }
      inMetadata = true;
      continue;
    }

    if (rawVal.length > 0 && !rawVal.startsWith(' ')) {
      logError(`${filePath}:${lineNum}: Invalid YAML key-value syntax: missing space after colon in "${trimmed}"`);
      hasSyntaxError = true;
      continue;
    }

    const val = rawVal.trim();

    if (val.startsWith('"')) {
      if (!/^"(?:[^"\\]|\\.)*"$/.test(val)) {
        logError(`${filePath}:${lineNum}: Unclosed quote or unexpected trailing characters after quote: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }
      result[key] = val.slice(1, -1);
    } else if (val.startsWith("'")) {
      if (!/^'[^']*'$/.test(val)) {
        logError(`${filePath}:${lineNum}: Unclosed quote or unexpected trailing characters after quote: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }
      result[key] = val.slice(1, -1);
    } else {
      // Flow indicators balance checks
      const openBrackets = (val.match(/\[/g) || []).length;
      const closeBrackets = (val.match(/\]/g) || []).length;
      if (openBrackets !== closeBrackets) {
        logError(`${filePath}:${lineNum}: Unbalanced square brackets in YAML value: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }

      const openBraces = (val.match(/\{/g) || []).length;
      const closeBraces = (val.match(/\}/g) || []).length;
      if (openBraces !== closeBraces) {
        logError(`${filePath}:${lineNum}: Unbalanced curly braces in YAML value: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }

      // Check for unclosed quote inside unquoted text
      const doubleQuoteCount = (val.match(/"/g) || []).length;
      if (doubleQuoteCount % 2 !== 0) {
        logError(`${filePath}:${lineNum}: Unbalanced double-quote in unquoted YAML value: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }
      const singleQuoteCount = (val.match(/'/g) || []).length;
      if (singleQuoteCount % 2 !== 0) {
        logError(`${filePath}:${lineNum}: Unbalanced single-quote in unquoted YAML value: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }

      if (val.includes(': ')) {
        logError(`${filePath}:${lineNum}: Unquoted YAML string contains colon followed by space (must be quoted): "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }
      if (val.startsWith('@') || val.startsWith('%') || val.startsWith('`')) {
        logError(`${filePath}:${lineNum}: Invalid starting character in unquoted YAML value: "${trimmed}"`);
        hasSyntaxError = true;
        continue;
      }
      result[key] = val;
    }
  }

  if (hasSyntaxError) {
    return null;
  }
  return result;
}

/**
 * Scans a single file against generic secret, path, and restricted term patterns.
 * Never prints matched secrets or sensitive strings to the log.
 */
function scanFileDlp(filePath) {
  let content;
  try {
    content = fs.readFileSync(filePath, 'utf8');
  } catch (err) {
    return; // binary or unreadable
  }

  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    for (const pat of GENERIC_DLP_PATTERNS) {
      if (pat.regex.test(line)) {
        logError(`${filePath}:${i + 1}: Sensitive pattern detected (${pat.name}) [REDACTED]`);
      }
    }
    if (hasCustomRestrictedTerm(line)) {
      logError(`${filePath}:${i + 1}: Restricted term detected in content [REDACTED]`);
    }
  }
}

/**
 * Scans all repository files outside ref/, .git/, and node_modules.
 * Scans both file/directory names and file contents.
 */
function scanRepositoryDlp() {
  console.log('\n--- Running Global DLP & Leak Prevention Scan ---');
  const scanned = [];

  function walk(dir) {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const ent of entries) {
      if (ent.name === '.git' || ent.name === 'ref' || ent.name === 'node_modules') continue;
      const full = path.join(dir, ent.name);
      const rel = path.relative(REPO_ROOT, full);

      // Check file/directory names for custom restricted terms
      if (hasCustomRestrictedTerm(ent.name) || hasCustomRestrictedTerm(rel)) {
        logError(`[PATH REDACTED]: Restricted term detected in file or directory name`);
      }

      // Check file/directory names for sensitive paths
      for (const pat of GENERIC_DLP_PATTERNS) {
        if (pat.regex.test(ent.name) || pat.regex.test(rel)) {
          logError(`[PATH REDACTED]: Sensitive pattern detected in file or directory name (${pat.name})`);
        }
      }

      if (ent.isDirectory()) {
        walk(full);
      } else if (ent.isFile()) {
        scanned.push(full);
        scanFileDlp(full);
      }
    }
  }

  walk(REPO_ROOT);
  logOk(`Scanned ${scanned.length} files across entire repository for sensitive patterns and paths.`);
}

function validateSkills() {
  console.log('\n--- Validating Skills in stable/skills/ ---');
  if (!fs.existsSync(STABLE_SKILLS_DIR)) {
    logError(`Directory not found: ${STABLE_SKILLS_DIR}`);
    return [];
  }

  const entries = fs.readdirSync(STABLE_SKILLS_DIR, { withFileTypes: true });
  const validatedSkills = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const skillName = entry.name;
    const skillDir = path.join(STABLE_SKILLS_DIR, skillName);
    const skillFile = path.join(skillDir, 'SKILL.md');

    if (!KEBAB_CASE_RE.test(skillName)) {
      logError(`Skill directory name is not valid kebab-case: ${skillName}`);
    }

    if (!fs.existsSync(skillFile)) {
      logError(`Missing SKILL.md in ${skillDir}`);
      continue;
    }

    const content = fs.readFileSync(skillFile, 'utf8');
    const fm = parseYamlFrontmatter(content, skillFile);
    if (!fm) continue;

    if (fm.name !== skillName) {
      logError(`${skillFile}: Frontmatter name ("${fm.name}") does not match directory name ("${skillName}")`);
    }

    if (!fm.description || fm.description.trim().length === 0) {
      logError(`${skillFile}: Frontmatter description is empty or missing`);
    } else if (fm.description.length > 1024) {
      logError(`${skillFile}: Frontmatter description exceeds 1024 characters (${fm.description.length} chars)`);
    }

    const ALLOWED_ROOT_FIELDS = new Set(['name', 'description', 'license', 'metadata', 'compatibility']);
    for (const k of Object.keys(fm)) {
      if (!ALLOWED_ROOT_FIELDS.has(k)) {
        logWarn(`${skillFile}: Non-standard root frontmatter field "${k}" should be placed inside "metadata:"`);
      }
    }

    validatedSkills.push({
      name: skillName,
      path: path.relative(REPO_ROOT, skillDir),
      skillFilePath: skillFile,
      sha256: sha256File(skillFile),
      description: fm.description,
    });

    logOk(`Skill ${skillName} passed specification validation`);
  }

  return validatedSkills;
}

function validateAgents() {
  console.log('\n--- Validating Agents in stable/agents/ ---');
  if (!fs.existsSync(STABLE_AGENTS_DIR)) {
    logError(`Directory not found: ${STABLE_AGENTS_DIR}`);
    return [];
  }

  const files = fs.readdirSync(STABLE_AGENTS_DIR);
  const validatedAgents = [];

  for (const file of files) {
    if (!file.endsWith('.md')) continue;
    const agentPath = path.join(STABLE_AGENTS_DIR, file);

    const content = fs.readFileSync(agentPath, 'utf8');
    const fm = parseYamlFrontmatter(content, agentPath);
    if (!fm) continue;

    const expectedName = file.replace(/\.md$/, '');
    if (fm.name !== expectedName) {
      logError(`${agentPath}: Agent frontmatter name ("${fm.name}") does not match file stem ("${expectedName}")`);
    }

    validatedAgents.push({
      name: expectedName,
      path: path.relative(REPO_ROOT, agentPath),
      sha256: sha256File(agentPath),
      description: fm.description,
    });

    logOk(`Agent ${expectedName} passed validation`);
  }

  return validatedAgents;
}

function validateTools() {
  console.log('\n--- Validating Tools in tools/ ---');
  if (!fs.existsSync(TOOLS_DIR)) {
    logError(`Directory not found: ${TOOLS_DIR}`);
    return [];
  }

  const entries = fs.readdirSync(TOOLS_DIR, { withFileTypes: true });
  const validatedTools = [];

  for (const entry of entries) {
    if (!entry.isFile()) continue;
    const fileName = entry.name;
    const fullPath = path.join(TOOLS_DIR, fileName);
    const relPath = path.join('tools', fileName);

    if (!fileName.endsWith('.sh') && !fileName.endsWith('.ps1') && !fileName.endsWith('.js')) {
      continue;
    }

    validatedTools.push({
      fileName,
      relPath,
      sha256: sha256File(fullPath)
    });

    logOk(`Tool ${fileName} discovered on disk`);
  }

  return validatedTools;
}

/**
 * Validates a catalog manifest, verifies artifact paths, entryFiles, exact SHA-256 checksums,
 * directory traversal protection, and ensures 100% catalog coverage for skills, agents, and tools.
 */
function validateCatalogFile(catalogPath, catalogLabel, discoveredSkills, discoveredAgents, discoveredTools) {
  console.log(`\n--- Validating ${catalogLabel} (${path.relative(REPO_ROOT, catalogPath)}) ---`);
  if (!fs.existsSync(catalogPath)) {
    logError(`${catalogLabel} not found at ${catalogPath}`);
    return;
  }

  let catalog;
  try {
    catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
  } catch (err) {
    logError(`Failed to parse ${catalogLabel}: ${err.message}`);
    return;
  }

  if (!catalog.schemaVersion || !Array.isArray(catalog.artifacts)) {
    logError(`${catalogLabel} missing required fields: schemaVersion, artifacts`);
    return;
  }

  const ids = new Set();
  const catalogSkillNames = new Set();
  const catalogAgentNames = new Set();
  const catalogEntryFiles = new Set();

  const REQUIRED_FIELDS = ['id', 'name', 'type', 'status', 'version', 'path', 'entryFile', 'sha256', 'description', 'compatibility'];

  for (const art of catalog.artifacts) {
    if (ids.has(art.id)) {
      logError(`${catalogLabel}: Duplicate artifact ID "${art.id}"`);
    }
    ids.add(art.id);

    for (const f of REQUIRED_FIELDS) {
      if (art[f] === undefined || art[f] === null || art[f] === '') {
        logError(`${catalogLabel} - ${art.id}: Missing required catalog field "${f}"`);
      }
    }

    // Path traversal and absolute path protection
    if (!art.path || art.path.includes('..') || path.isAbsolute(art.path) || art.path.startsWith('/') || art.path.includes('\\')) {
      logError(`${catalogLabel} - ${art.id}: Path traversal or invalid path: "${art.path}"`);
    }
    if (!art.entryFile || art.entryFile.includes('..') || path.isAbsolute(art.entryFile) || art.entryFile.startsWith('/') || art.entryFile.includes('\\')) {
      logError(`${catalogLabel} - ${art.id}: Path traversal or invalid entryFile: "${art.entryFile}"`);
    }

    const artPath = path.resolve(REPO_ROOT, art.path || '');
    if (!artPath.startsWith(REPO_ROOT + path.sep)) {
      logError(`${catalogLabel} - ${art.id}: Path escapes repository root: "${art.path}"`);
    } else if (!fs.existsSync(artPath)) {
      logError(`${catalogLabel} - ${art.id}: Path does not exist on disk: ${art.path}`);
    }

    const entryFilePath = path.resolve(REPO_ROOT, art.entryFile || '');
    if (!entryFilePath.startsWith(REPO_ROOT + path.sep)) {
      logError(`${catalogLabel} - ${art.id}: entryFile escapes repository root: "${art.entryFile}"`);
    } else if (!fs.existsSync(entryFilePath)) {
      logError(`${catalogLabel} - ${art.id}: entryFile does not exist on disk: ${art.entryFile}`);
    } else {
      const diskSha256 = sha256File(entryFilePath);
      if (art.sha256 !== diskSha256) {
        logError(`${catalogLabel} - ${art.id} (${art.entryFile}): SHA256 mismatch!\n    Catalog: ${art.sha256}\n    Disk:    ${diskSha256}`);
      }
    }

    catalogEntryFiles.add(art.entryFile);

    if (art.type === 'skill') {
      catalogSkillNames.add(art.name);
    } else if (art.type === 'agent') {
      catalogAgentNames.add(art.name);
    }
  }

  // Ensure all discovered skills on disk are cataloged
  for (const skill of discoveredSkills) {
    if (!catalogSkillNames.has(skill.name)) {
      logError(`${catalogLabel}: Skill "${skill.name}" on disk is not registered`);
    }
  }

  // Ensure all discovered agents on disk are cataloged
  for (const agent of discoveredAgents) {
    if (!catalogAgentNames.has(agent.name)) {
      logError(`${catalogLabel}: Agent "${agent.name}" on disk is not registered`);
    }
  }

  // Ensure all discovered tools on disk are cataloged
  for (const tool of discoveredTools) {
    if (!catalogEntryFiles.has(tool.relPath)) {
      logError(`${catalogLabel}: Tool "${tool.fileName}" on disk (${tool.relPath}) is not registered in catalog`);
    }
  }

  logOk(`${catalogLabel} validated: ${catalog.artifacts.length} artifacts verified with checksums and boundary checks.`);
}

function run() {
  console.log('Starting validation suite for resources-generative-ai...');
  scanRepositoryDlp();
  const skills = validateSkills();
  const agents = validateAgents();
  const tools = validateTools();
  validateCatalogFile(CATALOG_EN_PATH, 'catalog.json (EN)', skills, agents, tools);
  validateCatalogFile(CATALOG_PT_PATH, 'catalog.pt-BR.json (PT-BR)', skills, agents, tools);

  console.log('\n======================================');
  if (errors > 0) {
    console.error(`Validation FAILED with ${errors} error(s) and ${warnings} warning(s).`);
    process.exit(1);
  } else {
    console.log(`Validation PASSED successfully with ${warnings} warning(s).`);
    process.exit(0);
  }
}

run();
