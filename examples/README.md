# Examples

Small, runnable test files to copy from. Each folder holds one script and the
test file next to it. Run all of them with `tlio-test examples` (from the
`tlio-test` folder: `dotnet run --project src/Tlio.Test.Cli -- examples`).

CI runs these on every change, so they are always correct.

| Folder | Shows |
|---|---|
| [`check-values`](check-values) | Every kind of check: `equals`, `exists` / `absent`, `count`, `each`, `contains`, `matches`, `approx`, `isType` |
| [`invoice-enrich`](invoice-enrich) | Scripts that stamp a time and an id: leave them out, check their shape (`isType: datetime`, `near: now`, `matches`), or pin them (`clock`, `seed`) |
| [`whole-document`](whole-document) | `expectFull` with `ignore` for the parts that change; `unlistedPaths: fail` (strict) |
| [`loops`](loops) | A script with `forEach`; `expectError` for a script that is meant to refuse (or, today, does) |
| [`fixtures-and-settings`](fixtures-and-settings) | Input from a file, `description`, and `timeoutMs` set for the file and overridden for one case |
| [`yaml-script`](yaml-script) | A script written in YAML instead of JSON |
| [`yaml-documents`](yaml-documents) | `dataFormat: yaml`: transforming a YAML document |
| [`xml-order`](xml-order) | `dataFormat: xml`: XPath paths; an element is checked as its text |
| [`convert-formats`](convert-formats) | A script that converts JSON to XML partway; checks are written for the final document |

## Which style should my test use?

1. **Start with `expect`** and list only the values the script is responsible
   for. This is the default because it keeps working when the script gains an
   unrelated field.
2. **Anything that changes between runs** (times, generated ids): do not check
   it, or check what it looks like, or pin it with `clock` / `seed`.
3. **Use `expectFull`** when the output is small and fully predictable, or when
   you are moving a case over from the designer. Add `ignore` for the odd
   volatile field.
4. **Use `unlistedPaths: fail`** for scripts where an unexpected new field would
   be a mistake (a script that builds a message for another system, say).
5. **Add an `expectError` case** for input the script should refuse.

## What a failure looks like

```
examples/check-values/order-summary.test.yaml
  FAIL  exact values (equals)
        $.total  expected 14.75, got 15.75
```

and for a whole document, the paths that differ:

```
  FAIL  the order comes back accepted
        $.status  values differ
          expected: "accepted"
          actual:   "rejected"
        $.currency  not expected in the output
```
