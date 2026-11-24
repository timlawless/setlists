import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const migration = readFileSync(new URL('../sql/schema_v14_offline_operation_idempotency.sql', import.meta.url), 'utf8');

test('v14 validates song edit objects and rejects an empty changed-fields object', () => {
  assert.match(migration, /jsonb_typeof\(v_set\)\s+is\s+distinct\s+from\s+'object'/i);
  assert.match(migration, /v_set\s*=\s*'\{\}'::jsonb/i);
});

test('v14 does not reference unsupported JSON object length functions', () => {
  assert.doesNotMatch(migration, /\bjsonb?_object_length\s*\(/i);
});
