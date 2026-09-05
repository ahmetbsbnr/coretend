// SPDX-License-Identifier: Apache-2.0
// SPDX-FileCopyrightText: The CoreTend Authors
//
// A small token-bucket rate limiter backed by whatever the store persists
// (Postgres row in production, Map in tests). Pure arithmetic here; the store
// only reads/writes { tokens, updatedMs }.
//
// The key handed in is already a salted hash of the client IP (see
// respond.clientKey) — the raw address is never stored.

"use strict";

// Refill `capacity` tokens over `windowMs`; each request costs 1.
async function take(store, key, { capacity = 5, windowMs = 60_000, now = Date.now() } = {}) {
  const ratePerMs = capacity / windowMs;
  const prior = (await store.rateGet(key)) || { tokens: capacity, updatedMs: now };

  const elapsed = Math.max(0, now - prior.updatedMs);
  let tokens = Math.min(capacity, prior.tokens + elapsed * ratePerMs);

  let allowed = false;
  if (tokens >= 1) {
    tokens -= 1;
    allowed = true;
  }

  await store.rateSet(key, { tokens, updatedMs: now });

  const retryAfterMs = allowed ? 0 : Math.ceil((1 - tokens) / ratePerMs);
  return { allowed, remaining: Math.floor(tokens), retryAfterMs };
}

module.exports = { take };
