#!/usr/bin/env node

/**
 * skeleton.js — Template renderer for easy-proxy nginx configurations
 * Replaces skeleton.py (Python 2 → Node.js)
 *
 * Usage:
 *   skeleton.js -t /path/to/template.conf --server_name=example.com --domain=example.com ...
 *
 * Simple string interpolation: $(variable_name) or ${variable_name} in templates
 */

const fs = require('fs');
const path = require('path');
const yargs = require('yargs/yargs');
const { hideBin } = require('yargs/helpers');

const CONFIG_FILE = '/usr/local/share/easy/skeleton.conf';

function main() {
  const argv = yargs(hideBin(process.argv))
    .option('t', {
      alias: 'template-file',
      describe: 'Use template file',
      type: 'string',
      demandOption: true,
    })
    .option('c', {
      alias: 'config-file',
      describe: 'Use a different config file',
      type: 'string',
      default: CONFIG_FILE,
    })
    .option('server_name', {
      type: 'string',
      default: '',
    })
    .option('domain', {
      type: 'string',
      default: '',
    })
    .option('location_path', {
      type: 'string',
      default: '/',
    })
    .option('location_target', {
      type: 'string',
      default: '',
    })
    .strict()
    .help()
    .parseSync();

  const templateFile = argv.t;
  const configFile = argv.c;

  // Validate template file exists
  if (!fs.existsSync(templateFile)) {
    console.error(`ERROR: template file ${templateFile} not found`);
    process.exit(1);
  }

  // Validate config file exists (but don't require contents)
  if (configFile && configFile !== CONFIG_FILE && !fs.existsSync(configFile)) {
    console.error(`ERROR: config file ${configFile} not found`);
    process.exit(1);
  }

  // Read template
  let template;
  try {
    template = fs.readFileSync(templateFile, 'utf-8');
  } catch (err) {
    console.error(`ERROR: unable to read template file: ${err.message}`);
    process.exit(1);
  }

  // Build variable dictionary (all CLI args except argv/_ at the end)
  const variables = {
    server_name: argv.server_name,
    domain: argv.domain,
    location_path: argv.location_path,
    location_target: argv.location_target,
  };

  // Simple variable substitution: ${ var_name } → value
  let rendered = template;
  for (const [key, value] of Object.entries(variables)) {
    // Match ${key} or $key (both forms)
    const regexBraces = new RegExp(`\\$\\{${key}\\}`, 'g');
    const regexPlain = new RegExp(`\\$${key}\\b`, 'g');
    rendered = rendered.replace(regexBraces, value || '');
    rendered = rendered.replace(regexPlain, value || '');
  }

  // Output result
  console.log(rendered);
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(`ERROR: ${err.message}`);
    process.exit(1);
  }
}

module.exports = { main };
