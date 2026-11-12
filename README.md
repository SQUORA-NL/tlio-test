# tlio-test

Run your TLio script tests in GitHub Actions, Azure DevOps or any CI, and fail
the build when a script no longer produces the output your tests expect.

You keep scripts and test files in your own repository. A test file lists the
values that matter, so output that changes on every run (timestamps, generated
ids) does not make tests flaky. It runs on its own: no server, no database, no
.NET to install.

```yaml
# .github/workflows/tlio-tests.yml
- uses: actions/checkout@v4
- uses: SQUORA-NL/tlio-test@v1.0.0
  with:
    paths: scripts
```

## Start here

| I want to... | Read |
|---|---|
| Write a test file | [Testing your scripts in CI](docs/script-ci-testing.md) |
| Set up GitHub Actions or Azure DevOps | [Setting up the pipeline](docs/script-ci-pipelines.md), with copy-paste files in [`pipelines/`](pipelines) |
| Copy a working example | [`examples/`](examples/README.md) |
| Get my cases out of the TLio designer | **Download tests** in the designer's Tests tab; see the first guide |

## Contents of this repository

| Path | What |
|---|---|
| `action.yml` | The GitHub Action: `uses: SQUORA-NL/tlio-test@v1.0.0` |
| `azure/tlio-test.yml` | Azure DevOps step template |
| `install.sh` | Downloads, checksum-verifies and unpacks the binary; works on any CI |
| `pipelines/` | Complete pipeline files to copy |
| `examples/` | Runnable example scripts and tests |
| `docs/` | The guides |
| Releases | The binaries for Linux (x64), macOS (Apple silicon) and Windows (x64), with checksums |

This repository is published from the TLio platform repository on each release;
please do not edit it by hand. Questions and problems: open an issue here.

## Without a pipeline

Download the binary for your system from the latest release and run:

```
tlio-test scripts
```

Exit codes: `0` all passed, `1` a case failed, `2` a test file is invalid or the
arguments are wrong, `3` no tests were found.
