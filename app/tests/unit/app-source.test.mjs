import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

const appSource = readFileSync(join(process.cwd(), 'App.js'), 'utf8');
const serverSource = readFileSync(join(process.cwd(), 'server.mjs'), 'utf8');

test('Disease Scout keeps the core judge-visible workflow in the app shell', () => {
  for (const expected of [
    'Disease Scout Memory',
    'Glasses view',
    'Scout assessment',
    'Supervisor packet',
    'DiseaseScoutObservation JSON',
    'Output verifier',
  ]) {
    assert.match(appSource, new RegExp(expected.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')));
  }
});

test('Disease Scout preserves the safety posture', () => {
  assert.match(appSource, /treatment_recommendation:\s*null/);
  assert.match(appSource, /External sends are disabled in this demo/);
  assert.match(appSource, /Camera-button auto-launch remains a device test, not a claim/);
  assert.match(serverSource, /Never recommend chemical treatment, sprays, removal, or field action/);
});

test('Model endpoint remains behind the local proxy instead of browser secrets', () => {
  assert.match(appSource, /EXPO_PUBLIC_DISEASE_SCOUT_API_URL/);
  assert.match(appSource, /window\.location\?\.hostname/);
  assert.match(appSource, /localhost:8787/);
  assert.match(appSource, /\/api\/scout\/analyze/);
  assert.doesNotMatch(appSource, /OPENAI_API_KEY|GEMINI_API_KEY|DISCORD_/);
});

test('Server supports a swappable Gemini provider behind the same schema', () => {
  assert.match(serverSource, /SUPPORTED_PROVIDERS = new Set\(\['codex-cli', 'openai', 'gemini'\]\)/);
  assert.match(serverSource, /DISEASE_SCOUT_GEMINI_MODEL/);
  assert.match(serverSource, /GEMINI_API_KEY \|\| process\.env\.GOOGLE_API_KEY/);
  assert.match(serverSource, /function validateObservationShape/);
  assert.match(serverSource, /gemini_generate_content_vision/);
});

test('Uploaded evidence failures are queued instead of faked', () => {
  assert.match(appSource, /DEFERRED_QUEUE_KEY/);
  assert.match(appSource, /queueDeferredAnalysis/);
  assert.match(appSource, /Retry queued analysis/);
  assert.match(appSource, /needs_connectivity/);
  assert.match(appSource, /Capture was queued locally for retry/);
});
