const fs = require('node:fs');
const path = require('node:path');
const { expect, test } = require('@playwright/test');

const screenshotDir = path.resolve(__dirname, '../../../final_docs/overnight');
const viewports = [
  { name: 'desktop', width: 1440, height: 1000 },
  { name: 'mobile-390', width: 390, height: 844 },
  { name: 'mobile-360', width: 360, height: 740 },
  { name: 'display-600', width: 600, height: 600 },
];

const onePixelPng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
  'base64',
);

const successfulObservation = {
  observation: {
    observation_id: 'zone-b-zone-b-suspicious',
    worker_id: 'worker-07',
    crop: 'tomato',
    zone: 'Zone B',
    image_uri: 'web-upload://leaf.png',
    capture_source: 'web_upload',
    upload_filename: 'leaf.png',
    upload_size_bytes: onePixelPng.length,
    upload_mime_type: 'image/png',
    report_channel: 'typed_report_voice_stand_in',
    wearer_note: 'yellowing and spots on lower leaves',
    possible_disease: 'possible early blight or leaf spot',
    confidence: 'medium',
    limitation_flags: ['single_view_only', 'underside_missing'],
    evidence_quality: 'single uploaded image; underside missing',
    next_check: 'Capture the underside of the affected leaf.',
    supervisor_action: 'Supervisor should review the evidence packet before field action.',
    review_status: 'supervisor_review',
    treatment_recommendation: null,
    finding_why: 'Yellowing and clustered spots are visible, but a single view is not enough for diagnosis.',
    broad_state: 'disease_like',
    visible_symptoms: ['yellowing', 'dark spots'],
    send_status: 'not_sent_demo_only',
    analysis_source: 'test_model',
    model_name: 'test-model',
    model_latency_ms: 1,
  },
};

test.describe('Disease Scout baseline interface', () => {
  for (const viewport of viewports) {
    test(`captures ${viewport.name} packet screenshot and layout metrics`, async ({ page }, testInfo) => {
      fs.mkdirSync(screenshotDir, { recursive: true });
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto('/', { waitUntil: 'networkidle' });

      await expect(page.getByText('Disease Scout Memory')).toBeVisible();
      await expect(page.getByText('Glasses view')).toBeVisible();
      await expect(page.getByText('Scout assessment')).toBeVisible();

      const report = page.getByPlaceholder('Type the worker report...');
      await report.fill('yellowing and spots on lower leaves');
      await page.getByText('Trigger capture', { exact: true }).click();
      await page.getByText('Ask identify disease', { exact: true }).click();
      await page.getByText('Ask why', { exact: true }).last().click();
      await page.getByText('Create supervisor packet', { exact: true }).click();

      await expect(page.getByText('Ready for review')).toBeVisible();
      await expect(page.getByText('DiseaseScoutObservation JSON')).toBeVisible();
      await page.evaluate(() => {
        window.scrollTo(0, 0);
        document.documentElement.scrollTop = 0;
        document.body.scrollTop = 0;
        for (const element of document.querySelectorAll('*')) {
          element.scrollTop = 0;
          element.scrollLeft = 0;
        }
      });
      await page.waitForTimeout(100);

      const metrics = await page.evaluate(() => {
        const root = document.getElementById('root');
        const documentWidth = Math.max(
          document.documentElement.scrollWidth,
          document.body.scrollWidth,
          root ? root.scrollWidth : 0,
        );
        const visibleButtons = Array.from(document.querySelectorAll('[role="button"], button')).length;
        return {
          viewportWidth: window.innerWidth,
          documentWidth,
          horizontalOverflowPx: Math.max(0, documentWidth - window.innerWidth),
          visibleButtons,
          bodyTextLength: document.body.innerText.length,
        };
      });

      await testInfo.attach(`${viewport.name}-layout-metrics`, {
        body: JSON.stringify(metrics, null, 2),
        contentType: 'application/json',
      });

      const screenshotPath = path.join(screenshotDir, `baseline-${viewport.name}.png`);
      await page.screenshot({ path: screenshotPath, fullPage: true });
      expect(metrics.bodyTextLength).toBeGreaterThan(500);
      expect(metrics.horizontalOverflowPx).toBeLessThanOrEqual(2);
    });
  }
});

test('queues uploaded evidence when analysis is unavailable and retries later', async ({ page }) => {
  let calls = 0;
  await page.route('http://localhost:8787/api/scout/analyze', async (route) => {
    calls += 1;
    if (calls === 1) {
      await route.abort('failed');
      return;
    }
    await route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify(successfulObservation),
    });
  });

  await page.goto('/', { waitUntil: 'networkidle' });
  await page.getByPlaceholder('Type the worker report...').fill('yellowing and spots on lower leaves');
  await page.locator('input[type="file"]').setInputFiles({
    name: 'leaf.png',
    mimeType: 'image/png',
    buffer: onePixelPng,
  });
  await page.getByText('Trigger capture', { exact: true }).click();
  await page.getByText('Ask identify disease', { exact: true }).click();

  await expect(page.getByText('Deferred processing')).toBeVisible();
  await expect(page.getByText(/needs_connectivity:/i)).toBeVisible();
  await expect(page.getByText(/queued locally for retry/i)).toBeVisible();

  await page.getByText('Retry queued analysis', { exact: true }).click();
  await expect(page.getByText('possible early blight or leaf spot').first()).toBeVisible();
  await expect(page.getByText(/Queued capture processed/i)).toBeVisible();
});
