const fs = require('node:fs');
const path = require('node:path');
const { expect, test } = require('@playwright/test');

const imagePath = process.env.DISEASE_SCOUT_LIVE_UI_UPLOAD_IMAGE || '';
const reportText = process.env.DISEASE_SCOUT_LIVE_UI_UPLOAD_REPORT || 'yellowing and spots on lower leaves';
const outputDir = path.resolve(__dirname, '../../../final_docs/overnight');
const outputPath = process.env.DISEASE_SCOUT_LIVE_UI_UPLOAD_OUT
  ? path.resolve(process.env.DISEASE_SCOUT_LIVE_UI_UPLOAD_OUT)
  : path.join(outputDir, 'live-ui-upload-smoke.json');
const screenshotPath = process.env.DISEASE_SCOUT_LIVE_UI_UPLOAD_SCREENSHOT
  ? path.resolve(process.env.DISEASE_SCOUT_LIVE_UI_UPLOAD_SCREENSHOT)
  : path.join(outputDir, 'live-ui-upload-smoke.png');

test.skip(!imagePath, 'Set DISEASE_SCOUT_LIVE_UI_UPLOAD_IMAGE to run the live UI upload smoke.');

test('uploads a blind image through the browser and displays the live model result', async ({ page }) => {
  test.setTimeout(180_000);
  fs.mkdirSync(outputDir, { recursive: true });

  const image = path.resolve(imagePath);
  if (!fs.existsSync(image)) {
    throw new Error(`Missing live upload image: ${image}`);
  }

  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto('/', { waitUntil: 'networkidle' });

  await page.locator('input[type="file"]').setInputFiles(image);
  await expect(page.getByText(path.basename(image), { exact: true }).first()).toBeVisible();
  await page.getByPlaceholder('Type the worker report...').fill(reportText);
  await page.getByText('Trigger capture', { exact: true }).click();

  const responsePromise = page.waitForResponse(
    (response) => response.url().includes('/api/scout/analyze') && response.request().method() === 'POST',
    { timeout: 150_000 },
  );
  await page.getByText('Ask identify disease', { exact: true }).click();
  const response = await responsePromise;
  const payload = await response.json();

  expect(response.ok()).toBeTruthy();
  expect(payload.observation).toBeTruthy();
  expect(payload.observation.capture_source).toBe('web_upload');
  expect(payload.observation.upload_filename).toBe(path.basename(image));
  expect(payload.observation.wearer_note).toBe(reportText);
  expect(payload.observation.possible_disease).toBeTruthy();
  expect(payload.observation.confidence).toBeTruthy();
  expect(payload.observation.next_check).toBeTruthy();
  expect(payload.observation.treatment_recommendation).toBeNull();

  await expect(page.getByText(payload.observation.possible_disease).first()).toBeVisible({ timeout: 20_000 });
  await page.getByText('Ask why', { exact: true }).click();
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
  await page.screenshot({ path: screenshotPath, fullPage: true });

  const metrics = await page.evaluate(() => ({
    bodyTextLength: document.body.innerText.length,
    hasDeferredQueue: /Deferred processing/i.test(document.body.innerText),
    hasTreatmentAdviceText: /spray|pesticide|fungicide/i.test(document.body.innerText),
  }));

  const report = {
    generated_at: new Date().toISOString(),
    status: 'pass',
    web_url: process.env.DISEASE_SCOUT_WEB_URL || 'playwright-base-url',
    image_filename: path.basename(image),
    image_size_bytes: fs.statSync(image).size,
    report_text: reportText,
    response_status: response.status(),
    response_url: response.url(),
    screenshot: path.relative(path.resolve(__dirname, '../../..'), screenshotPath).replaceAll('\\', '/'),
    observation: payload.observation,
    checks: {
      browser_upload_reached_backend: true,
      capture_source_web_upload: payload.observation.capture_source === 'web_upload',
      upload_filename_preserved: payload.observation.upload_filename === path.basename(image),
      report_preserved: payload.observation.wearer_note === reportText,
      uncertainty_visible: Boolean(payload.observation.possible_disease && payload.observation.confidence),
      next_check_exists: Boolean(payload.observation.next_check),
      no_treatment_advice: payload.observation.treatment_recommendation === null,
      supervisor_packet_visible: true,
      body_text_length: metrics.bodyTextLength,
      treatment_words_visible: metrics.hasTreatmentAdviceText,
    },
  };

  fs.writeFileSync(outputPath, `${JSON.stringify(report, null, 2)}\n`, 'utf8');
});
