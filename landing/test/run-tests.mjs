import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
import { promises as fs } from 'node:fs';
import { createLandingServer } from '../server.mjs';

async function startServer(config = {}) {
  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'biotrack-landing-'));
  const dataFile = path.join(tmpDir, 'leads.json');
  const eventsFile = path.join(tmpDir, 'events.log');

  const server = createLandingServer({
    dataFile,
    eventsFile,
    baseUrl: 'http://example.test',
    ...config
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();

  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    dataFile,
    eventsFile,
    async cleanup() {
      await new Promise((resolve) => server.close(resolve));
      await fs.rm(tmpDir, { recursive: true, force: true });
    }
  };
}

function makeLeadPayload(overrides = {}) {
  return {
    first_name: 'Alice',
    last_name: 'Martin',
    email: 'alice@example.com',
    primary_goal: 'concentration',
    consent_marketing: true,
    source: 'manual',
    created_at: new Date().toISOString(),
    ...overrides
  };
}

async function runTest(name, fn) {
  try {
    await fn();
    console.log(`✓ ${name}`);
    return true;
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(error);
    return false;
  }
}

const tests = [
  {
    name: 'POST /api/leads creates a pending lead',
    fn: async () => {
      const ctx = await startServer();
      try {
        const response = await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload())
        });

        assert.equal(response.status, 201);
        const payload = await response.json();
        assert.equal(payload.success, true);
        assert.ok(payload.lead_id);

        const store = JSON.parse(await fs.readFile(ctx.dataFile, 'utf8'));
        assert.equal(store.leads.length, 1);
        assert.equal(store.leads[0].status, 'pending');
      } finally {
        await ctx.cleanup();
      }
    }
  },
  {
    name: 'POST /api/leads rejects duplicate emails',
    fn: async () => {
      const ctx = await startServer();
      try {
        await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload())
        });

        const second = await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload({ first_name: 'Alicia' }))
        });

        assert.equal(second.status, 409);
        const payload = await second.json();
        assert.equal(payload.error_code, 'EMAIL_ALREADY_EXISTS');
      } finally {
        await ctx.cleanup();
      }
    }
  },
  {
    name: 'POST /api/leads validates consent',
    fn: async () => {
      const ctx = await startServer();
      try {
        const response = await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload({ consent_marketing: false }))
        });

        assert.equal(response.status, 400);
        const payload = await response.json();
        assert.equal(payload.error_code, 'VALIDATION_ERROR');
        assert.ok(payload.fields.includes('consent_marketing'));
      } finally {
        await ctx.cleanup();
      }
    }
  },
  {
    name: 'POST /api/leads rate limits excessive requests',
    fn: async () => {
      const ctx = await startServer({ leadRateLimit: 1, leadRateWindowMs: 60_000 });
      try {
        const first = await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload())
        });
        assert.equal(first.status, 201);

        const second = await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload({ email: 'other@example.com' }))
        });

        assert.equal(second.status, 429);
      } finally {
        await ctx.cleanup();
      }
    }
  },
  {
    name: 'GET /api/leads/confirm marks lead as confirmed',
    fn: async () => {
      const ctx = await startServer();
      try {
        const create = await fetch(`${ctx.baseUrl}/api/leads`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json; charset=utf-8' },
          body: JSON.stringify(makeLeadPayload({ email: 'confirm@example.com' }))
        });
        assert.equal(create.status, 201);

        const store = JSON.parse(await fs.readFile(ctx.dataFile, 'utf8'));
        const token = store.leads[0].confirmation_token;
        assert.ok(token);

        const confirm = await fetch(`${ctx.baseUrl}/api/leads/confirm?token=${token}`, {
          method: 'GET',
          redirect: 'manual'
        });

        assert.equal(confirm.status, 302);
        assert.ok((confirm.headers.get('location') || '').includes('/merci.html?confirmed=1'));

        const updatedStore = JSON.parse(await fs.readFile(ctx.dataFile, 'utf8'));
        assert.equal(updatedStore.leads[0].status, 'confirmed');
      } finally {
        await ctx.cleanup();
      }
    }
  }
];

async function main() {
  let allPassed = true;
  for (const item of tests) {
    const passed = await runTest(item.name, item.fn);
    if (!passed) {
      allPassed = false;
    }
  }

  if (!allPassed) {
    process.exit(1);
  }

  console.log('All tests passed.');
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
