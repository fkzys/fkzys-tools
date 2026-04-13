# Tests

## Overview

| File | Language | Framework | What it tests |
|------|----------|-----------|---------------|
| `test_bash_lint.sh` | Bash | Custom assertions | bash-lint: all ERROR/WARN/INFO checkers, CLI flags (`--strict`, `--json`, `--help`, `-V`), `-p` project mode |
| `test_fkzys_audit.sh` | Bash | Custom assertions | fkzys-audit: common checks (license, depends, makefile, CI, test docs), language-specific (bash, go, csharp, python), CLI flags (`--all`, `--json`, `--lang`) |
| `test_bash_coverage.sh` | Bash | Custom assertions | bash-coverage: basic collection, percentage calculation, `-p` project mode, CLI flags (`--help`, `-V`), syntax |

## Running

```bash
# All tests
make test

# Individual suites
bash tests/test_bash_lint.sh
bash tests/test_fkzys_audit.sh
bash tests/test_bash_coverage.sh
```

## How they work

### Bash unit tests

All tests source `test_harness.sh`, which provides:
- **Assertion functions**: `ok`/`fail`
- **Section headers**: `section`
- **Summary**: `summary` with pass/fail counts

Each test creates temporary files via `mktemp`/`mktemp -d` with cleanup via `rm -rf` after each section. Test fixtures are minimal scripts organised in project-skeleton directories (`bin/`, `lib/`, `tests/`) designed to trigger specific checker behaviour.

## Test environment

- All tests create temporary directories (`mktemp -d`) cleaned up via `rm -rf` after each section
- No root privileges required
- No real system paths or configuration files are touched
