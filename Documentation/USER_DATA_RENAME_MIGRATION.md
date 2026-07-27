# User Data Rename Migration — moved

This file is a redirect, kept because `Sources/Persistence/LegacyDataMigration.swift`
and several rename-phase documents reference this path by name.

The migration is implemented and has shipped. The document that used to live
here was the *pre-implementation design*, and it opened by stating that no
migration code existed — true when written, false now. It was archived rather
than rewritten.

| Looking for | Read |
|---|---|
| The migration **as delivered and executed** — code, tests, data really migrated, limits | [`CORETEND_DATA_MIGRATION_REPORT.md`](CORETEND_DATA_MIGRATION_REPORT.md) |
| The original **pre-implementation design** (historical, verbatim) | [`RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_DESIGN.md`](RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_DESIGN.md) |
| The original **pre-implementation test plan** (historical, verbatim) | [`RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md`](RebrandHistory/PRE_IMPLEMENTATION_MIGRATION_TEST_PLAN.md) |
| Why internal migration/rollback records are absent from the public export | [`REPOSITORY_SANITIZATION.md`](REPOSITORY_SANITIZATION.md) |

Created during the 0.8.1 Final Canonical Audit Resync at
`92cbd08bc3cd1d8ad0513391cbd7552b520f09fe`. Left in place instead of editing
the doc comment in `LegacyDataMigration.swift`, so that `Sources/` stays
byte-identical to the tree the audited binaries were compiled from.
