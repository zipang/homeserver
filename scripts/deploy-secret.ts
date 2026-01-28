#!/usr/bin/env bun
import { $ } from "bun";
import { existsSync, mkdirSync } from "fs";
import { join, dirname } from "path";

/**
 * SKYLAB Secret Deployer
 * Usage: sudo bun scripts/deploy-secret.ts --template <file> --outputDir <path>
 */

const args = Bun.argv.slice(2);
const values: Record<string, string> = {};

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg.startsWith("--")) {
    const key = arg.slice(2);
    const value = args[++i];
    if (value) values[key] = value;
  }
}

const templateFile = values.template;
const outputDir = values.outputDir;

if (!templateFile || !outputDir) {
  console.error("Error: Missing required arguments.");
  console.error(
    "Usage: sudo bun scripts/deploy-secret.ts --template <file> --outputDir <path>",
  );
  if (!templateFile) console.error("  --template is missing");
  if (!outputDir) console.error("  --outputDir is missing");
  process.exit(1);
}

const secretsTemplateLocation = join(import.meta.dirname, "../secrets");
const TEMPLATE_PATH = join(secretsTemplateLocation, templateFile);
const OUTPUT_PATH = join(outputDir, templateFile);

if (!existsSync(TEMPLATE_PATH)) {
  console.error(`Error: Template not found at ${TEMPLATE_PATH}`);
  process.exit(1);
}

async function run() {
  console.log(`\x1b[36m--- SKYLAB Secret Deployer: ${templateFile} ---\x1b[0m`);

  const file = Bun.file(TEMPLATE_PATH);
  const text = await file.text();
  const lines = text.split("\n");

  let envContent = "";

  for (let line of lines) {
    line = line.trim();

    // Preserve empty lines
    if (line === "") {
      envContent += "\n";
      continue;
    }

    // Handle comments
    if (line.startsWith("#")) {
      console.log(`\x1b[34m${line}\x1b[0m`);
      envContent += `${line}\n`;
      continue;
    }

    // Handle variable declarations
    if (line.includes("=")) {
      const firstEqIndex = line.indexOf("=");
      const key = line.substring(0, firstEqIndex).trim();
      let expression = line.substring(firstEqIndex + 1).trim();

      let value = "";
      let saveToFile = false;

      if (expression.startsWith("file:")) {
        saveToFile = true;
        expression = expression.substring(5).trim();
      }

      if (expression.startsWith('prompt("')) {
        // Handle interactive prompt
        const promptMatch = expression.match(/prompt\("(.+)"\)/);
        const promptText = promptMatch
          ? promptMatch[1]
          : `Enter value for ${key}: `;
        value = prompt(promptText) || "";
      } else if (expression !== "") {
        // Handle command execution
        console.log(`\x1b[90mExecuting: ${expression}\x1b[0m`);
        try {
          const result = await $`${{ raw: expression }}`.text();
          value = result.trim();
        } catch (err) {
          console.error(
            `\x1b[31mError executing command for ${key}: ${err}\x1b[0m`,
          );
          process.exit(1);
        }
      } else {
        // Fallback for empty values
        value = prompt(`Enter value for ${key}: `) || "";
      }

      if (saveToFile) {
        const secretFileName = `${key.toLowerCase()}.secret`;
        const secretFilePath = join(outputDir, secretFileName);
        
        console.log(`\x1b[32mSaving ${key} to side-file: ${secretFilePath}\x1b[0m`);
        
        if (!existsSync(outputDir)) {
          mkdirSync(outputDir, { recursive: true });
        }
        
        await Bun.write(secretFilePath, value);
        await $`chmod 600 ${secretFilePath}`;
        
        // Add the _FILE variable to the env
        envContent += `${key}_FILE=${secretFilePath}\n`;
      } else if (value.includes("\n")) {
        // Handle multiline values by escaping newlines for systemd EnvironmentFile
        const escapedValue = value.replace(/\n/g, "\\\n");
        envContent += `${key}="${escapedValue}"\n`;
      } else {
        envContent += `${key}=${value}\n`;
      }
    }
  }

  // File generation complete
  console.log(`\x1b[32mFinal secret file (unencrypted)\x1b[0m`);
  console.log(envContent);

  try {
    // Write the final file
    await Bun.write(OUTPUT_PATH, envContent, { createPath: true });

    // Set restrictive permissions
    await $`chmod 600 ${OUTPUT_PATH}`;

    console.log(`\x1b[32mSuccess! Secrets saved to ${OUTPUT_PATH}\x1b[0m`);
    console.log(
      `\x1b[33mDon't forget to run 'update-nix' to apply changes.\x1b[0m`,
    );
  } catch (err) {
    console.error(`\x1b[31mFailed to save secrets: ${err}\x1b[0m`);
    process.exit(1);
  }
}

run();
