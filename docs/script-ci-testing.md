# Testing your scripts in CI

**Audience:** engineers who keep TLio scripts in their own Git repository and want a pull request to fail when a script stops producing the right output.

**Status:** built. Worked examples are in the `../examples` folder of this repository.

---

## What it is

`tlio-test` runs your scripts against the inputs you give it and checks the
output. You write the test cases in a file next to the script. A build step runs
them on every pull request, and the build fails if any case fails.

It runs on its own: no server, no database, no sign-in.

## Setting it up

The short version is below. For complete pipeline files, pull-request triggers,
branch protection, the Azure DevOps service connection and troubleshooting, see
[Setting up the pipeline](script-ci-pipelines.md).

You need two things in your repository: a script, and a test file for it.

```
scripts/
  invoice-enrich/
    invoice-enrich.json
    invoice-enrich.test.yaml
    fixtures/
      invoice-big.json
```

Then add one step to your pipeline.

**GitHub Actions**

```yaml
- uses: actions/checkout@v4
- uses: SQUORA-NL/tlio-test@v1.0.0
  with:
    paths: scripts
```

The action downloads the right build for the runner, checks its checksum, runs
the tests, and uploads the JUnit report. Inputs: `paths` (several, separated by
spaces), `version`, `filter`, `allow-empty`, `report`, and `token` if the
releases are in a private repository.

**Azure DevOps**

```yaml
resources:
  repositories:
    - repository: tlio
      type: github
      endpoint: <your GitHub service connection>
      name: SQUORA-NL/tlio-test
      ref: refs/tags/v1.0.0

steps:
  - checkout: self
  - template: azure/tlio-test.yml@tlio
    parameters:
      version: 1.0.0
      paths: scripts
```

The results appear in the pipeline's **Tests** tab.

Nothing else is needed on the agent: the tool is one self-contained file, so
there is no .NET to install. Microsoft-hosted and GitHub-hosted agents on Linux,
macOS (Apple silicon) and Windows are supported.

To try it on your machine first, download the build for your system from the
release page and run `tlio-test scripts`.

## Getting your cases out of the designer

If you already have test cases in the designer, open the script, go to the
**Tests** tab and choose **Download tests**. You get a zip named
`<script name>-tests.zip` holding a folder with two files:

```
Invoice enrich/
  Invoice enrich.json            the script, in its own notation
  Invoice enrich.test.yaml       its cases, as a test file
```

Unzip it into your repository and run `tlio-test .`. The download is what is on
screen, so a case you have edited but not saved goes out as edited.

Every case is written with `expectFull`, which is the designer's own rule (the
whole output must match), so a case means the same thing in both places. If a
script's output includes values that change on each run, edit the file: replace
`expectFull` with a list of `expect` checks on the values you care about, as
described below. A comment at the top of the file shows how.

For worked examples of every kind of check, see `../examples`.

## Writing a test file

A test file is YAML or JSON, named `<anything>.test.yaml` (or `.yml`, `.json`).
It has a `settings` block and a list of `cases`.

```yaml
settings:
  script: ./invoice-enrich.json

cases:
  - name: happy path
    input:
      file: ./fixtures/invoice-big.json
    expect:
      - path: $.total
        equals: 121.0
      - path: $.currency
        equals: EUR
```

- `input` is a `file:` (relative to the test file) or an inline `value:`. For
  XML and YAML documents use `text:`.
- Settings in the file apply to every case. A case can override them with its
  own `settings:`.

### Settings

| Setting | Default | What it does |
|---|---|---|
| `script` | required | The script to run, relative to the test file. |
| `dataFormat` | `json` | `json`, `xml` or `yaml`: the format of the input document. |
| `timeoutMs` | `10000` | A case that runs longer fails. |
| `unlistedPaths` | `ignore` | Set to `fail` to require every value in the output to be asserted or ignored. |
| `ignore` | none | Paths to leave out of comparison. |
| `clock` | real time | Pin "now" for date functions (see below). |
| `seed` | random | Pin generated ids (see below). |

## What a test checks

**Only what you list.** If the output has a hundred values and you assert three,
the other ninety-seven are not checked. This is what makes tests on
time-based output reliable: leave out the timestamp and it cannot break the
test.

Each line under `expect` is a `path` and one check:

| Check | Passes when |
|---|---|
| `equals: 121.0` | The value is exactly this. Objects and arrays are compared in full; key order does not matter. |
| `isType: datetime` | The value is of this type: `string`, `number`, `integer`, `boolean`, `object`, `array`, `null` or `datetime`. |
| `matches: "^INV-\\d+$"` | The text matches a regular expression. |
| `contains: "VAT"` | The text contains this, or the array has this element. |
| `approx: 10.5` + `tolerance: 0.01` | The number is within the tolerance. |
| `near: now` + `within: 5s` | The date is within that long of when the test ran. |
| `exists: true` / `absent: true` | There is a value at the path / there is not. |
| `count: 3` | The path finds exactly this many values. |

Paths are written the way they are in your script: JSONPath for JSON, XPath for
XML. A path that finds several values is an error unless you use `count` or add
`each: true`, which requires the check to hold for every value found.

**Quote paths that contain brackets.** In YAML, a path such as `$.items[0].name`
must be in quotes when it sits inside `{ }` on one line:

```yaml
- { path: "$.items[0].name", equals: Ada }     # quoted: fine
- path: $.items[0].name                         # on its own line: fine unquoted
  equals: Ada
```

For XML documents, set `dataFormat: xml` and give the input as `text:` or
`file:`. An element with no child elements is checked as its text, so
`/order/total` can equal `20`. See `../examples/xml-order`.

When you want every value in the output accounted for, set
`unlistedPaths: fail` in `settings` (JSON documents only). Any value that no
check and no `ignore` entry covers then fails the case, and is named.

### Time-based and generated values

Pick the simplest option that works:

1. **Leave it out.** Do not assert the field.
2. **Check its shape.** `isType: datetime`, `near: now`, or `matches` for an id.
3. **Pin it.** Set `clock: "2026-01-15T10:30:00Z"` and `seed: 42` in `settings`,
   and the date functions and generated ids give the same answer on every run,
   so you can assert exact values such as "due date is 30 days later". Only
   `=datetime()` and `=newGuid()` are pinned; functions that take a date as an
   argument already give the same answer every time. A pinned time comes back in
   the engine's usual form, so `10:30:00.000Z` is written `10:30:00Z` in the
   expectation.

### Whole-document comparison

If a script is fully predictable, check the whole output:

```yaml
    expectFull:
      total: 121.0
      currency: EUR
    # settings: { ignore: [$.audit] }  to drop volatile parts
```

### Expecting a failure

A script that should reject bad input:

```yaml
  - name: refuses a negative total
    input: { value: { total: -5 } }
    expectError: "total must be positive"
```

A case with no `expect`, `expectFull` or `expectError` only checks that the
script runs to the end.

## Reading the results

On failure you get the file, the case, the path, and what was expected and found:

```
FAIL invoice-enrich.test.yaml › happy path
  $.total   expected 121.0   got 120.0
```

In GitHub, failures appear as annotations on the pull request. In Azure DevOps
they appear in the Tests tab.

| Exit code | Meaning |
|---|---|
| 0 | Every case passed. |
| 1 | At least one case failed. |
| 2 | A test file is invalid (bad YAML, unknown check, script not found). |
| 3 | No tests were found. This fails the build on purpose, so a renamed folder cannot make CI pass by testing nothing. |

## Useful commands

```
tlio-test scripts                 run everything under scripts/
tlio-test --filter happy          only cases or files matching "happy"
tlio-test --list                  show what would run
tlio-test --validate              check test files without running scripts
tlio-test scripts --report junit=results.xml
```

## Good to know

- The CLI uses the same engine version as the platform. `tlio-test --version`
  prints it, so you can confirm that CI and the designer agree.
- Test cases saved in the designer are not picked up by this tool; the test file
  in your repository is the only source it reads.
