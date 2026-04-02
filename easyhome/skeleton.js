#!/usr/bin/env node

/**
 * skeleton.js — Template renderer for easy-proxy nginx configurations
 * Replaces skeleton.py (Python 2 → Node.js, zero dependencies)
 *
 * Usage:
 *   skeleton.js -t /path/to/template.conf --server_name=foo --domain=bar ...
 */

'use strict';

const fs = require('fs');

function parseArgs(argv) {
  const args = { t: null, c: null, server_name: '', domain: '', location_path: '/', location_target: '' };
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '-t' || arg === '--template-file') { args.t = argv[++i]; continue; }
    if (arg === '-c' || arg === '--config-file')   { args.c = argv[++i]; continue; }
    const m = arg.match(/^--(\w+)(?:=(.*))?$/);
    if (m) { args[m[1]] = m[2] !== undefined ? m[2] : (argv[++i] || ''); }
  }
  return args;
}

const args = parseArgs(process.argv);

if (!args.t) { console.error('ERROR: -t <template-file> required'); process.exit(1); }
if (!fs.existsSync(args.t)) { console.error('ERROR: template file not found: ' + args.t); process.exit(1); }

let tmpl = fs.readFileSync(args.t, 'utf-8');

const vars = { server_name: args.server_name, domain: args.domain, location_path: args.location_path, location_target: args.location_target };

for (const [k, v] of Object.entries(vars)) {
  tmpl = tmpl.replace(new RegExp('\\$\\{' + k + '\\}', 'g'), v || '');
  tmpl = tmpl.replace(new RegExp('\\$' + k + '\\b', 'g'), v || '');
}

// Unescape \$ → $ (Cheetah escape for literal nginx variables like \$upstream)
tmpl = tmpl.replace(/\\\$/g, '$');

process.stdout.write(tmpl);
