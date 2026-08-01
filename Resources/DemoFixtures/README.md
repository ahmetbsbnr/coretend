# CoreTend product demo fixture

`coretend-product.json` is the canonical, versioned example-data fixture for
product simulations, controlled screenshots, portfolio media and UI tests that
need deterministic content.

The fixture is deliberately not a release manifest and none of its sizes,
counts, filenames or activity dates describe a real Mac. Every module carries
the bilingual label `Example data` / `Données d’exemple`. The only permitted
example home is `/Users/demo`.

The fixture mirrors the eight destinations currently exposed by the app:
Dashboard, Storage, Space Lens, Duplicates, Applications, Integrity, Activity
and Settings. Hidden source modules must not be added as public destinations.
In particular, Similar Images remains outside this public fixture while it is
not a primary release module.

All byte values are integers. Aggregate values are exact sums:

- Storage totals its findings and its preselected findings separately.
- Space Lens totals its direct children.
- Duplicates totals every copy and computes reclaimable bytes while retaining
  exactly one keeper per group.
- Applications totals the app bundle, exact associated items and conservative
  leftover entries.
- Integrity totals only the example Download-provenance rows; notarization is
  explicitly `not-inspected` because the real app does not determine it.
- Activity totals all records and separates real cleanup bytes from simulated
  cleanup bytes.

Validate the canonical fixture:

```sh
python3 Scripts/check-demo-fixtures.py
```

Run the validator contract tests:

```sh
python3 -m unittest discover -s Tests/DemoFixturesValidatorTests -p 'test_*.py'
```

When the schema changes, increment `schemaVersion` and update the validator and
its negative tests in the same change. Consumers must display `sampleLabel` and
must not present these deterministic examples as measurements from the app.
