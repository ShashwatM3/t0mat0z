const { defineConfig, devices } = require('@playwright/test');

const baseURL = process.env.DISEASE_SCOUT_WEB_URL || 'http://127.0.0.1:19006';

module.exports = defineConfig({
  testDir: './tests/e2e',
  timeout: 45_000,
  expect: {
    timeout: 10_000,
  },
  reporter: [['list']],
  use: {
    baseURL,
    trace: 'retain-on-failure',
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
      },
    },
  ],
});
