# portable-hack-ast-linters-monolithic-checker

_A non-Hack distribution of PhaLinters to allow HTL packages to use portable-hack-ast-linters without circular dependencies._

### How to use

- Optionally install [the VSCode extension](https://open-vsx.org/extension/hershel-theodore-layton/dead-simple-lint-server-integration)[^1] and configure it in `.vscode/settings.json`.
  - `http://localhost:10641?format=json&action=lint-input` is a good default.
- Launch the server using the CLI instructions below.
- Make sure to configure the port is exposed to the host network in Docker.
- Lint the entire project using `curl http://localhost:10641`.
  - The following query parameters are supported:
    - `format=text/vscode-json`
      - `text` (default) output human readable text.
      - `vscode-json` output json for use with the extension.
    - `directories=src,tests`
      - A comma separated list of directory names relative to the project root.
      - Only effective when `action` is `lint-all`
    - `action=lint-all/lint-input`
      - `lint-all` (default) scan all `directories` for lint errors
      - `lint-input` lint the Hack source text sent in the request body.
- Lint files interactively by opening them in VSCode with the extension installed.

### CLI

This distribution of [PhaLinters](https://github.com/hershel-theodore-layton/portable-hack-ast-linters)
can be spawned using the `vendor/bin/hershel-theodore-layton/portable-hack-ast-linters-monolithic-checker/start.sh` script.
In the examples below `$START_SH` should expand to the script path above.

```SH
# Print help text and exit
$START_SH -h

# Interactive setup, scan for the bundle and prompts you to trust it.
# Hosts the http server on port 10641, or the port specified with `-p`.
$START_SH

# AFK setup which builds and runs the first portable-hack-ast-monolithic-checker-bundle.resource
# Skips the trust prompt, should only be used if you trust every file in the directory.
$START_SH -t

# AFK setup, point $START_SH to a bundle, skips the prompt.
# Recommended setup for CI pipelines
$START_SH -b "vendor/hershel-theodore-layton/portable-hack-ast-monolithic-checker/bin/portable-hack-ast-monolithic-checker-bundle.resource"
```

When running interactively, you may see the following prompt:

```
Found the following resource file.
./path/to/portable-hack-ast-linters-monolithic-checker-bundled.resource
If you trust the resource above, type 'I trust this resource' to build and run it.
```

When you type `I trust this resource`, you understand the risks involved with
compiling and running this resource.

### Dependency hacking

This package depends on `portable-hack-ast(-linters|-extras)` at build time,
but the bundled output does not. This bundling process allows `portable-hack-ast`
and `portable-hack-ast-extras` to use this package without circular dependencies.
This is accomplished by publishing an empty `composer.json` file.

When developing this bundle, you must select the composer file with dependencies.
Set the [`COMPOSER`](https://getcomposer.org/doc/03-cli.md#composer) environment
variable to `composer-with-dependencies.json`.

```SH
COMPOSER=composer-with-dependencies.json composer update
```

This will install the dependencies, whereas `composer update` without the
environment variable set will not install anything.

### Developing

Since the bundle can't depend on any unbundled code, for example `hhvm-autoload`,
developing this package requires the ini setting`hhvm.autoload.enabled=true`.
Downstream consumers don't need native autoloading, since the bundle includes
all the dependencies in a single file.

When you are testing live (not the bundle itself), you can start the server using:

```SH
hhvm -m server -p 8080 -vServer.AllowRunAsRoot=1 -dhhvm.server.global_document=src/main.hack
```

If you want to test the bundle, use the following command:

```SH
./build.sh && bin/start.sh -p 8080 \
-b bin/portable-hack-ast-linters-monolithic-checker-bundled.resource
```

This will rebuild, recompile and start the lint-server.

[^1]:
    This extension is available on open-vsx.org at the time of writing.
    Stock VSCode is configured to load extensions from the VSCode Marketplace.
    If you are using VSCode, download and install the `.vsix` file.
    If you are using a VSCode fork, such as VSCodium, you can find the
    extension in the extension search tab, since VSCode forks use open-vsx.
