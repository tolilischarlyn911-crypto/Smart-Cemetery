const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const admin = require('firebase-admin');
const { chromium } = require('playwright-core');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
process.env.FIREBASE_STORAGE_EMULATOR_HOST ??= '127.0.0.1:9198';
admin.initializeApp({
  projectId: 'demo-smart-cemetery',
  storageBucket: 'demo-smart-cemetery.appspot.com',
});

async function fill(page, name, value) {
  const field = page.getByRole('textbox', { name });
  for (let attempt = 0; attempt < 4; attempt++) {
    await field.click();
    await page.waitForTimeout(150);
    await field.fill(value);
    await page.waitForTimeout(150);
    if (await field.inputValue() === value) return;
  }
  throw new Error(`Could not fill ${name}`);
}

async function main() {
  const payment = admin.firestore().doc('payments/demo-annual-fee');
  const before = (await payment.get()).data();
  assert.ok(before, 'Seed the local emulator first');
  const folder = fs.mkdtempSync(path.join(os.tmpdir(), 'cemetery-receipt-'));
  const fixture = path.join(folder, 'receipt-smoke.pdf');
  fs.writeFileSync(fixture, '%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\n%%EOF\n');
  const browser = await chromium.launch({
    executablePath: process.env.CHROME_PATH ||
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true,
  });
  const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
  let uploaded;
  try {
    await page.goto(process.env.ADMIN_EMULATOR_URL || 'http://127.0.0.1:8087/');
    await fill(page, 'Email', 'admin@demo.test');
    await fill(page, 'Password', 'Admin123!');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.getByText('Total Burials').waitFor();
    await page.getByText('Payments & Leases').first().click();
    const menu = page.getByRole('button', { name: 'Manage payment' }).first();
    await menu.waitFor();
    await menu.click();
    await page.waitForTimeout(300);
    await page.mouse.click(1305, 250);
    await page.getByText('ADD SUPPORTING FILES').waitFor();
    const picker = page.waitForEvent('filechooser');
    await page.getByText('ADD SUPPORTING FILES').click();
    await (await picker).setFiles(fixture);
    await page.getByText('receipt-smoke.pdf').waitFor();
    await page.getByRole('button', { name: 'Save', exact: true }).click();
    let after;
    for (let attempt = 0; attempt < 20; attempt++) {
      await page.waitForTimeout(500);
      after = (await payment.get()).data();
      if ((after.attachments || []).length > (before.attachments || []).length) break;
    }
    assert.equal((after.attachments || []).length, (before.attachments || []).length + 1);
    uploaded = after.attachments.at(-1).source;
    const [contents] = await admin.storage().bucket().file(uploaded).download();
    assert.ok(contents.toString().startsWith('%PDF-1.4'));
    console.log('Connected payment attachment upload and download passed.');
  } catch (error) {
    console.error((await page.locator('body').innerText()).slice(-800));
    await page.screenshot({ path: '/tmp/smart-cemetery-payment-smoke-failure.png' });
    throw error;
  } finally {
    if (!uploaded) {
      const latest = (await payment.get()).data();
      uploaded = (latest.attachments || [])
        .find((attachment) => attachment.name === 'receipt-smoke.pdf')?.source;
    }
    await payment.set(before);
    if (uploaded) await admin.storage().bucket().file(uploaded).delete().catch(() => {});
    await browser.close();
    fs.rmSync(folder, { recursive: true, force: true });
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
