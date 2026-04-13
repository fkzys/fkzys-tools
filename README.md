# fkzys-tools

Linting, coverage, and project audit tools for the fkzys ecosystem.

## Tools

### bash-lint

Linter that checks bash scripts against ecosystem conventions (spec §0.1, §2, §7, §11). See the [specs](https://gitlab.com/fkzys/specs/-/blob/main/README.md) for the full specification.

```bash
# Check specific files
bash-lint bin/atomic-upgrade lib/atomic/common.sh

# Check entire project
bash-lint -p ./atomic-upgrade

# Strict mode (warnings = errors)
bash-lint --strict -p ./gitpkg

# JSON output
bash-lint --json -p ./keys-vault | jq '.errors'
```

**Checks performed:**

| Level | Check | Spec Reference |
|-------|-------|---------------|
| ERROR | `set -euo pipefail` in entry points | §2 |
| ERROR | `verify-lib` sourcing | §2 |
| ERROR | No `eval` in config parsing | §2 |
| ERROR | ERROR/WARN messages to stderr | §2 |
| ERROR | No `chmod 777` | §11 |
| ERROR | No hardcoded secrets | §11 |
| WARN | `_NO_INIT` before sourcing library | §2 |
| WARN | Config whitelist + `printf -v` | §2 |
| WARN | Config ownership check | §2 |
| WARN | Cleanup trap with `set +e` | §2 |
| WARN | `shopt` save/restore | §2 |
| WARN | Glob `nullglob` | §2 |
| WARN | Input validation for paths (`_validate_path`) | §2 |
| WARN | Library arrays without nameref (`local -n`) | §2 |
| WARN | Function naming: snake_case | §2 |
| WARN | CLI `--help`/`--version` support | §2 |
| WARN | Test files should NOT have `-e` | §7 |
| WARN | Sourcing without `verify-lib` wrapper | §2 |
| WARN | Avoid `/tmp` for script files | §0.1 |
| INFO | Shebang convention | §2 |
| INFO | `readonly` constants | §2 |

### bash-coverage

Measures which lines of bash scripts are executed during test runs. Uses `BASH_ENV` + `DEBUG` trap — no source file modifications needed.

```bash
# Measure coverage for specific test
bash-coverage -- bash tests/test_config.sh

# Auto-discover and run all tests in tests/
bash-coverage -p ./atomic-upgrade

# Filter to specific files
bash-coverage --include 'common\.sh' -- bash tests/test.sh

# Enforce minimum coverage
bash-coverage --min-coverage 80 -- make test
```

### fkzys-audit

Project structure audit that checks conformance to the ecosystem specification across all supported languages. Unlike `bash-lint` (which checks bash code), `fkzys-audit` checks **project structure**: Makefiles, CI configuration, test documentation, language-specific conventions.

```bash
# Audit current directory
fkzys-audit

# Audit specific project
fkzys-audit ./atomic-upgrade

# Show INFO-level suggestions
fkzys-audit --all ./atomic-upgrade

# Check only Go conventions
fkzys-audit --lang go ./my-go-project

# JSON output
fkzys-audit --json ./atomic-upgrade | jq '.warnings'
```

**Checks performed:**

| Scope | Check | Spec Reference |
|-------|-------|---------------|
| All | LICENSE file | §14 |
| All | `depends` format (`system:pkg`, `gitpkg:pkg`) | §10 |
| All | Makefile: `install`, `test`, `PREFIX=/usr` | §3 |
| All | CI: `paths` filter, direct test calls | §15 |
| All | Test documentation: `tests/README.md` or `tests.md` | §7 |
| Bash | Entry: shebang, `set -euo pipefail` | §2 |
| Bash | Library: `#!/usr/bin/env bash` | §2 |
| Bash | man pages, completions | §8, §8.1 |
| Bash | `test_harness.sh` | §7 |
| Go | `cmd/<name>/` entry points | §6 |
| Go | `internal/` private packages | §6 |
| Go | Build flags: `CGO_ENABLED=0`, `-trimpath` | §6 |
| C# | `.csproj` structure | §13 |
| C# | xUnit test project | §13 |
| Python | `__main__.py` for CLI tools | §4 |

## Installation

```bash
make install      # sudo make install
make uninstall    # sudo make uninstall
make test         # run all tests
```

## Dependencies

- `bash` ≥ 4.4 (nameref, BASH_SOURCE, BASH_LINENO)
- `grep` (with `-E`, `-c`, `-o` support)
- `pandoc` (optional, for man page generation)
