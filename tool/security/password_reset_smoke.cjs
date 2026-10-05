const assert = require('node:assert/strict');
const { chromium } = require('playwright-core');

const url = process.env.ADMIN_EMULATOR_URL || 'http://127.0.0.1:8087/';
const chrome = process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const oobUrl = 'http://127.0.0.1:9098/emulator/v1/projects/demo-smart-cemetery/oobCodes';
const email = 'admin@demo.test';

async function resetCount() {
  const response = await fetch(oobUrl);
  assert.equal(response.ok, true, `Auth emulator returned ${response.status}`);
  const data = await response.json();
  return (data.oobCodes || []).filter(
    (code) => code.email === email && code.requestType === 'PASSWORD_RESET',
  ).length;
}

async function main() {
  const before = await resetCount();
  const browser = await chromium.launch({ executablePath: chrome, headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.goto(url);
    const field = page.getByRole('textbox', { name: 'Email' });
    await field.waitFor();
    await field.fill(email);
    await page.getByText('Forgot password?').click();
    let after = before;
    for (let attempt = 0; attempt < 30 && after === before; attempt++) {
      await page.waitForTimeout(200);
      after = await resetCount();
    }
    assert.equal(after, before + 1);
    assert.deepEqual(errors, []);
    console.log('Admin reset request reached the Auth emulator from a phone-width login page.');
  } finally {
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
