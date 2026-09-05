// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// Applies migrations/*.sql in filename order against POSTGRES_URL, skipping
// any file already recorded in schema_migrations. Deterministic; safe to run
// repeatedly. Run it once per deploy (or wire it into the Vercel build).
//
//   POSTGRES_URL=postgres://... node scripts/migrate.mjs
//   node scripts/migrate.mjs --dry-run   # list what would run, connect nothing

import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const DIR = join(HERE, "..", "migrations");
const dryRun = process.argv.includes("--dry-run");

const files = readdirSync(DIR)
  .filter((f) => f.endsWith(".sql"))
  .sort();

if (files.length === 0) {
  console.log("no migrations found");
  process.exit(0);
}

if (dryRun) {
  console.log("migrations on disk (filename order):");
  for (const f of files) console.log("  " + f);
  process.exit(0);
}

if (!process.env.POSTGRES_URL && !process.env.POSTGRES_PRISMA_URL) {
  console.error("POSTGRES_URL is not set — cannot migrate. (EXTERNAL CONFIGURATION REQUIRED)");
  process.exit(1);
}

const { sql } = await import("@vercel/postgres");

await sql`CREATE TABLE IF NOT EXISTS schema_migrations (
  filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`;

const { rows } = await sql`SELECT filename FROM schema_migrations`;
const done = new Set(rows.map((r) => r.filename));

let applied = 0;
for (const file of files) {
  if (done.has(file)) {
    console.log(`skip  ${file} (already applied)`);
    continue;
  }
  const ddl = readFileSync(join(DIR, file), "utf8");
  console.log(`apply ${file} …`);
  await sql.query(ddl);
  await sql`INSERT INTO schema_migrations (filename) VALUES (${file})`;
  applied += 1;
}

console.log(applied === 0 ? "database already up to date" : `applied ${applied} migration(s)`);
