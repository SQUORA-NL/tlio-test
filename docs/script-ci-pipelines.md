# Setting up the pipeline: GitHub Actions and Azure DevOps

**Audience:** whoever owns the repository where the scripts and test files live, and has to make a pull request run them.

**Before you start:** write at least one test file. See [Testing your scripts in CI](script-ci-testing.md) for the file format and `../examples` for samples. Ready-to-copy pipeline files are in `../pipelines/`.

> **Status:** these pipelines are written against the documented behaviour of GitHub Actions and Azure DevOps, and the tool they run was checked end to end locally. They have not yet been run on either service. If a step misbehaves on its first run, the troubleshooting section at the end lists what to look at first, and a report back is welcome.

---

## What you need

1. A repository with your scripts and test files, for example:

   ```
   scripts/
     invoice-enrich/
       invoice-enrich.json
       invoice-enrich.test.yaml
   ```

2. A released version of `tlio-test`. The examples use `1.0.0`. Releases are listed under the repository's **Releases** page, tagged `v<version>`.

Nothing else: no server, no database, no .NET on the build machine.

**Check it locally first.** Download the binary for your system from the release, then:

```
tlio-test scripts
```

If that is green on your machine, a failure in the pipeline is about the pipeline, not about your tests.

---

## GitHub Actions

### 1. Add the workflow

Copy `../pipelines/github-actions.yml` to `.github/workflows/tlio-tests.yml` in your repository:

```yaml
name: TLio script tests

on:
  pull_request:
    paths: ["scripts/**", ".github/workflows/tlio-tests.yml"]
  push:
    branches: [main]
    paths: ["scripts/**"]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: SQUORA-NL/tlio-test@v1.0.0
        with:
          version: 1.0.0
          paths: scripts
```

Change `scripts/**` and `paths: scripts` to wherever your scripts are. The `paths` filter means the workflow only runs when scripts or tests change; remove it to run on every pull request.

### 2. What the action does

It downloads the right build for the runner, verifies its checksum, runs the tests, and uploads the JUnit report as the artifact `tlio-test-results`. It works on `ubuntu-latest`, `windows-latest` and `macos-latest` (Apple silicon).

| Input | Default | Meaning |
|---|---|---|
| `paths` | `.` | Test files or folders, separated by spaces |
| `version` | newest release | The tool version, for example `1.0.0` |
| `filter` | none | Only cases or files whose name contains this text |
| `allow-empty` | `false` | Do not fail when no tests are found |
| `report` | `tlio-test-results.xml` | Where to write the JUnit report; empty for none |
| `token` | none | Only for private mirrors of the releases |
| `repository` | `SQUORA-NL/tlio-test` | Where the releases are |

### 3. Make it block merging

A workflow that fails does not stop a merge by itself. In the repository: **Settings -> Branches -> Branch protection rules** (or **Rulesets**) for `main`, enable **Require status checks to pass before merging**, and select the check named **test** (the job's name, shown as `TLio script tests / test`). If you used a `paths` filter, note that a required check that never runs shows as "waiting" on pull requests that do not match; either drop the filter for the required check or keep the job running always.

### 4. Reading the results

- On the pull request, each failing case appears as an **annotation** on the file with the failing value (`$.total: expected 121, got 120`).
- The job log lists every case and, for failures, the path, expected and actual value.
- The **Artifacts** section of the run has `tlio-test-results` (JUnit XML).

---

## Azure DevOps

### 1. Create a GitHub service connection

The `tlio-test` template lives on GitHub, and Azure DevOps fetches templates from GitHub through a service connection, even for a public repository.

**Project settings -> Service connections -> New service connection -> GitHub**, authorise it, and note its name (for example `my-github-connection`). It only needs to read public repositories.

### 2. Add the pipeline file

Copy `../pipelines/azure-pipelines.yml` to the root of your repository:

```yaml
trigger:
  branches: { include: [main] }
  paths: { include: [scripts] }

pr:
  branches: { include: [main] }
  paths: { include: [scripts] }

resources:
  repositories:
    - repository: tlio
      type: github
      endpoint: my-github-connection
      name: SQUORA-NL/tlio-test
      ref: refs/tags/v1.0.0

pool:
  vmImage: ubuntu-latest

steps:
  - checkout: self
  - template: azure/tlio-test.yml@tlio
    parameters:
      version: 1.0.0
      paths: scripts
```

Then **Pipelines -> New pipeline -> choose your repository -> Existing Azure Pipelines YAML file**. The first run asks you to permit access to the service connection.

### 3. Template parameters

| Parameter | Default | Meaning |
|---|---|---|
| `version` | `latest` | Tool version. Pin it; the installer is fetched at the matching tag |
| `paths` | `.` | Test files or folders, separated by spaces |
| `filter` | none | Only cases or files whose name contains this text |
| `allowEmpty` | `false` | Do not fail when no tests are found |
| `token` | none | Only for private mirrors; pass a secret variable |
| `repository` | `SQUORA-NL/tlio-test` | Where the releases are |

The template needs a bash shell, which Microsoft-hosted Linux, macOS and Windows agents all have.

### 4. Pull requests

- **Repository on GitHub:** the `pr:` section above runs the pipeline on pull requests.
- **Repository in Azure Repos:** `pr:` is ignored. Add a branch policy instead: **Repos -> Branches -> (...) on `main` -> Branch policies -> Build validation -> Add**, choose the pipeline, set it to **Required**. Optionally set a path filter such as `/scripts/*`.

### 5. Reading the results

The step publishes the JUnit report, so the run has a **Tests** tab with each case, its time and its failure message. Failing cases also appear as errors in the run summary, and the step fails, which fails the build.

---

## Any other CI system

The tool is one file. Anywhere you can run a shell:

```bash
curl -fsSL https://raw.githubusercontent.com/SQUORA-NL/tlio-test/v1.0.0/install.sh -o install.sh
dir="$(bash install.sh 1.0.0)"
"$dir/tlio-test" scripts --report junit=tlio-test-results.xml
```

The exit code is the contract: `0` all passed, `1` a case failed, `2` a test file is invalid or the arguments are wrong, `3` no tests were found.

---

## Keeping it current

- **Pin the version** in both the tag (`@v1.0.0` / `ref: refs/tags/v1.0.0`) and the `version` input. The two together mean a pipeline never changes underneath you.
- **To upgrade**, change both to the new version in a pull request; the pull request's own run shows whether your tests still pass on it.
- `tlio-test --version` prints the tool version and the TLio engine version, so you can confirm CI runs the same engine as the designer.

---

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| Exit code 3, "no tests found" | The `paths` folder is wrong, or files are not named `*.test.yaml`, `*.test.yml` or `*.test.json`. Run `tlio-test --list <paths>` locally. |
| Exit code 2, "INVALID" | A test file has a mistake; the message names the case and the key, and suggests a fix for typos. Run `tlio-test --validate` locally. |
| YAML error mentioning an alias or `[` | A path with brackets must be in quotes inside `{ }`: `{ path: "$.items[0].name", equals: x }`. |
| A case passes locally but fails in CI | Compare `tlio-test --version`; check the test does not depend on the current time or a random id (see "Time-based and generated values"). |
| "checksum mismatch" | The download was corrupted or intercepted. Re-run; if it persists, the release assets are not intact. |
| `404` while downloading | The version does not exist as a release (`v<version>`). |
| Azure: "repository resource not found" or a permission prompt | The service connection name is wrong or has not been authorised for this pipeline. Open the failed run and choose **Permit**. |
| Azure: template not found | The `ref` tag does not exist, or the path is not `azure/tlio-test.yml@tlio`. |
| GitHub: required check stays "Waiting for status" | The workflow has a `paths` filter and the pull request did not match it. Remove the filter or the requirement. |
| Windows agent: "bash not found" | The step needs Git Bash; Microsoft-hosted and GitHub-hosted Windows images include it. Self-hosted agents need Git for Windows installed. |
