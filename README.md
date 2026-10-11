# portable-hack-ast-linters-server

_A non-Hack distribution of PhaLinters to allow HTL packages to use portable-hack-ast-linters without circular dependencies._

### New in 2025: Express Docker Native Setup for HTL development

HTL containers recently became Docker Native. A simple `docker compose up`
will automate a lot of the process described in [how to use](#how-to-use).
The `CMD` of the [Dockerfile](./Dockerfile) passes `-s -g -e`.
This sets up your `.vscode/settings.json` for local development, runs the
embedded bundle, and caches the compiled repository under `/var/tmp`.

If this is your first time developing HTL, VSCode will display this prompt
after a restart:

```
Do you want to install the recommended extensions from
pranayagarwal and Hershel Theodore Layton for this repository?
```

[PranayAgarwal](https://github.com/PranayAgarwal) is an ex-Slack developer
who wrote [VSCode Hack](https://github.com/slackhq/vscode-hack), the Hack
language extension for VSCode. This extension provides rich Hack language and
HHVM support to VSCode. A must-have extension for syntax highlighting, inline
squiggles, autocomplete, go to definition, and so much more.

[Hershel Theodore Layton](https://github.com/hershel-theodore-layton/) is
a pseudonymous Open Source Software developer who wrote
[Portable Hack AST Linters Server](./README.md) and many other Hack Open Source
libraries. [This extension](https://open-vsx.org/extension/hershel-theodore-layton/dead-simple-lint-server-integration)[^1]
listens to changes in your source code and asks a local hhvm http server for
squiggles and autofixes.

After installing those extensions, your development environment is ready.

### How to use

- Optionally install [the VSCode extension](https://open-vsx.org/extension/hershel-theodore-layton/dead-simple-lint-server-integration)[^1] and configure it in `.vscode/settings.json`.
  - `http://localhost:10641?format=vscode-json&action=lint-input` is a good default.
- Launch the server using the CLI instructions below.
- Make sure the port is exposed to the host network in Docker.
- Lint the entire project using `curl http://localhost:10641`.
  - The following query parameters are supported:
    - `format=text/vscode-json`
      - `text` (default) output human-readable text.
      - `vscode-json` output JSON for use with the extension.
    - `directories=src,tests`
      - A comma-separated list of directory names relative to the project root.
      - Only effective when `action` is `lint-all`
    - `action=lint-all/lint-input`
      - `lint-all` (default) scans all `directories` for lint errors
      - `lint-input` lint the Hack source text sent in the request body.
- Lint files interactively by opening them in VSCode with the extension installed.

### CLI

This distribution of [PhaLinters](https://github.com/hershel-theodore-layton/portable-hack-ast-linters)
can be spawned using the `vendor/bin/pha-linters-server.sh` script.
In the examples below `$SERVER_SH` should expand to the script path above.

```SH
# Print help text
$SERVER_SH -h

# Run the embedded bundle on port 10641.
$SERVER_SH -e

# Set up VS Code for Docker Native development
$SERVER_SH -e -s -g

# Supply your own bundle path
$SERVER_SH -b /path/to/file.resource
```

### Dependency hacking

This package depends on `portable-hack-ast(-linters|-extras)` at build time,
but the bundled output does not. This bundling process allows `portable-hack-ast`
and `portable-hack-ast-extras` to use this package without circular dependencies.
This is accomplished by publishing an empty `composer.json` file.

When developing this bundle, you must select the composer file with dependencies.
Set the [`COMPOSER`](https://getcomposer.org/doc/03-cli.md#composer) environment
variable to `composer.dev.json`.

```SH
COMPOSER=composer.dev.json composer update
```

This will install the dependencies, whereas `composer update` without the
environment variable set will not install anything.

### Developing

Since the bundle can't depend on any unbundled code, for example `hhvm-autoload`,
developing this package requires the ini setting `hhvm.autoload.enabled=true`.
Downstream consumers don't need native autoloading, since the bundle includes
all the dependencies in a single file.

Run `bin/build.hack` to regenerate the embedded launcher and standalone resource.

[^1]:
    This extension is available on open-vsx.org at the time of writing.
    Stock VSCode is configured to load extensions from the VSCode Marketplace.
    If you are using VSCode, download and install the `.vsix` file.
    If you are using a VSCode fork, such as VSCodium, you can find the
    extension in the extension search tab, since VSCode forks use open-vsx.
