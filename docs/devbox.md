# Devbox

Devbox is a command-line tool that creates isolated, reproducible development environments using Nix. It lets you define project-specific packages in a `devbox.json` file and spin up shells with those tools installed - without polluting your system or dealing with version conflicts.

Devbox is configured via `modules/programs/devbox.nix`.

## Why Use Devbox?

- **Isolated environments**: Each project gets its own set of tools without affecting the rest of the system
- **Reproducible**: Share a `devbox.json` file and everyone gets the exact same environment
- **No version conflicts**: Work on multiple projects requiring different versions of the same tool
- **Fast**: No virtualization overhead - runs directly on your system using Nix

## Configuration Reference

The complete list of Devbox CLI commands can be found in the [official documentation](https://www.jetify.com/docs/devbox/cli-reference/devbox/).

## Quick Start

### Create a New Development Environment

```bash
# Enter the devbox shell
devbox shell
```

## Managing Specific Tools

Devbox is the right place to pin a tool to a version *for one project*, without
touching the system profile. Note that Devbox resolves packages from Nixpkgs, so
the resulting binaries are still read-only store paths and cannot self-update
(`npm -g`, `bun upgrade`, `pip install -U` will all fail with `EROFS`).

> **Bun is installed system-wide**, not via Devbox. See [Bun](./bun.md) for why
> it comes from the `nixpkgs-unstable` package set and how to upgrade it.

### Installing a project-scoped tool

1.  **Initialize a Devbox project** in your desired working directory (if you haven't already):
    ```bash
    devbox init
    ```
    This creates `devbox.json` and `devbox.lock` files.

2.  **Add the tool to your Devbox environment**:
    ```bash
    devbox add bun
    ```
    Devbox will fetch the latest stable version available in its catalog. If you
    need a specific version, specify it: `devbox add bun@1.3.3`.

3.  **Enter the Devbox shell**:
    ```bash
    devbox shell
    ```
    Now, when you run `bun --version`, it will be the version managed by Devbox.

4.  **Upgrade it**:
    ```bash
    devbox update bun
    ```
    This updates the package within `devbox.json` and `devbox.lock` — it is the
    Nix-native equivalent of `bun upgrade`.

5.  **Exit the Devbox shell**:
    ```bash
    exit
    ```

### The devbox.json File

Devbox stores its configuration in `devbox.json`. A typical file looks like:

```json
{
  "packages": [
    "python@3.12",
    "nodejs@20",
    "ripgrep"
  ],
  "shell": {
    "init_hook": "echo 'Welcome to the dev environment!'"
  }
}
```

### Essential Commands

| Command | Description |
|---------|-------------|
| `devbox init` | Initialize a new devbox project |
| `devbox add <pkg>` | Add a package to the environment |
| `devbox rm <pkg>` | Remove a package |
| `devbox shell` | Enter an isolated shell with your packages |
| `devbox run <script>` | Run a script defined in devbox.json |
| `devbox search <term>` | Search for available packages |
| `devbox update` | Update all packages to latest versions |
| `devbox info <pkg>` | Show package details and plugins |

## Using Devbox Global

Devbox can also be used as a global package manager for tools you want available everywhere:

```bash
# Add a tool globally
devbox global add neovim
devbox global add fzf

# List global packages
devbox global list

# Enter a shell with global packages
devbox global shell
```

## Generating Containers

Devbox can generate Dockerfiles and devcontainer configurations:

```bash
# Generate a Dockerfile
devbox generate dockerfile

# Generate devcontainer configuration
devbox generate devcontainer
```

## Integration with direnv

For automatic environment activation when entering a directory:

```bash
# Generate .envrc for direnv
devbox generate direnv
```

Then install and enable [direnv](https://direnv.net/) in your shell.

## Version Pinning

The `devbox.lock` file ensures reproducible builds. Always commit both files:

```bash
git add devbox.json devbox.lock
```

To pin specific versions:

```bash
# Add a specific version
devbox add python@3.10

# Use Nixpkgs commit for exact reproducibility
devbox add python --platforms python@nixpkgs/<commit-hash>
```

## Troubleshooting

### First shell is slow

The first `devbox shell` invocation downloads package catalogs. Subsequent runs are much faster.

### Package not found

Search across all channels:

```bash
devbox search <package> --show-all
```

### Clear cache

```bash
devbox cache clean
```

### View devbox version

```bash
devbox version
```

## Further Reading

- [Official Documentation](https://www.jetify.com/docs/devbox/)
- [devbox.json Reference](https://www.jetify.com/docs/devbox/configuration/)
- [Example Projects](https://github.com/jetify-com/devbox/tree/main/examples)
