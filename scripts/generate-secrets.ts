#!/usr/bin/env bun
import { $ } from "bun";
import { existsSync } from "fs";
import { join } from "path";
import { parseArgs } from "util";

/**
 * SKYLAB Reusable Secret Generator
 * Usage: bun scripts/generate-secrets.ts --template <file> --sshPublicKey <path> --outputDir <path>
 */

const { values } = parseArgs({
  args: Bun.argv.slice(2),
  options: {
    template: { type: "string" },
    sshPublicKey: { type: "string" },
    outputDir: { type: "string" },
  },
  strict: false,
});

const { templateFile, publicKeyPath, outputDir } = values;

if (!templateFile || !publicKeyPath || !outputDir) {
  console.error(
    "Usage: generate-secrets --template <file> --sshPublicKey <path> --outputDir <path>",
  );
  process.exit(1);
}

const secretsTemplateLocation = join(import.meta.dirname, "../secrets");
const TEMPLATE_PATH = join(secretsTemplateLocation, templateFile);
const OUTPUT_PATH = join(outputDir, templateFile);

if (!existsSync(TEMPLATE_PATH)) {
  console.error(`Error: Template not found at ${TEMPLATE_PATH}`);
  process.exit(1);
}

if (!existsSync(publicKeyPath)) {
  console.error(`Error: Public key not found at ${publicKeyPath}`);
  process.exit(1);
}

async function run() {
  console.log(
    `\x1b[36m--- SKYLAB Secret Generator: ${templateFile} ---\x1b[0m`,
  );

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

      // Handle multiline values (like RSA keys) by wrapping in single quotes
      if (value.includes("\n")) {
        envContent += `${key}='${value}'\n`;
      } else {
        envContent += `${key}=${value}\n`;
      }
    }
  }

  // Ensure output directory exists (requires sudo if running on server)
  if (!existsSync(outputDir)) {
    console.log(`Creating directory ${outputDir}...`);
    await $`sudo mkdir -p ${outputDir}`;
    await $`sudo chown $USER ${outputDir}`;
  }

  // Encrypt with SOPS
  console.log(`\x1b[32mEncrypting secrets with sops...\x1b[0m`);

  try {
    const sopsProcess = Bun.spawn(
      [
        "sops",
        "--encrypt",
        "--ssh-public-key",
        publicKeyPath,
        "--input-type",
        "env",
        "--output-type",
        "env",
        "/dev/stdin",
      ],
      {
        stdin: "pipe",
      },
    );

    sopsProcess.stdin.write(envContent);
    sopsProcess.stdin.end();

    const encryptedContent = await new Response(sopsProcess.stdout).text();

    // Write the final file
    await Bun.write(`${TEMPLATE_PATH}.tmp`, encryptedContent);
    await $`sudo mv ${TEMPLATE_PATH}.tmp ${OUTPUT_PATH}`;

    // We'll leave it as root:root for now, or let NixOS manage it via sops-nix
    await $`sudo chmod 600 ${OUTPUT_PATH}`;

    console.log(`\x1b[32mSuccess! Secrets saved to ${OUTPUT_PATH}\x1b[0m`);
    console.log(
      `\x1b[33mDon't forget to run 'update-nix' to apply changes.\x1b[0m`,
    );
  } catch (err) {
    console.error(`\x1b[31mFailed to encrypt secrets: ${err}\x1b[0m`);
    process.exit(1);
  }
}

run();
