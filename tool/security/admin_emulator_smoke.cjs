const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { chromium } = require('playwright-core');

const url = process.env.ADMIN_EMULATOR_URL || 'http://127.0.0.1:8087/';
const chrome = process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
admin.initializeApp({ projectId: 'demo-smart-cemetery' });

async function signIn(page, email, password) {
  await page.getByRole('textbox', { name: 'Email' }).waitFor();
  for (const [name, value] of [['Email', email], ['Password', password]]) {
    const field = page.getByRole('textbox', { name });
    for (let attempt = 0; attempt < 3; attempt++) {
      await field.click();
      await page.waitForTimeout(150);
      await field.fill(value);
      await page.waitForTimeout(100);
      if (await field.inputValue() === value) break;
    }
    assert.equal(await field.inputValue(), value);
  }
  await page.getByText('Sign in', { exact: true }).click();
}

async function main() {
  const browser = await chromium.launch({ executablePath: chrome, headless: true });
  const errors = [];
  const adminRole = admin.firestore().doc('users/demo-admin');
  const staffRole = admin.firestore().doc('users/demo-staff');
  try {
    const visitor = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    visitor.on('pageerror', (error) => errors.push(error.stack || error.message));
    await visitor.goto(url);
    await signIn(visitor, 'visitor@demo.test', 'Visitor123!');
    await visitor.getByText('Administrator or staff access is required.').waitFor();
    await visitor.getByText('Sign out').click();
    await visitor.getByRole('textbox', { name: 'Email' }).waitFor();
    await visitor.close();

    const staff = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    staff.on('pageerror', (error) => errors.push(error.stack || error.message));
    await staff.goto(url);
    await signIn(staff, 'staff@demo.test', 'Staff123!');
    await staff.getByText('Grave Management').waitFor();
    assert.equal(await staff.getByText('User Management').count(), 0);
    assert.equal(await staff.getByText('Payments & Leases').count(), 0);
    await staff.getByText('Maintenance', { exact: true }).first().click();
    await staff.getByText('Review and update reported issues').waitFor();
    await staffRole.update({ role: 'visitor' });
    await staff.getByText('Administrator or staff access is required.').waitFor();
    await staffRole.update({ role: 'staff' });
    await staff.getByText('Grave Management').waitFor();
    await staff.getByText('Logout').click();
    await staff.getByRole('textbox', { name: 'Email' }).waitFor();
    await staff.close();

    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    page.on('pageerror', (error) => errors.push(error.stack || error.message));
    await page.goto(url);
    await signIn(page, 'admin@demo.test', 'Admin123!');
    await page.getByText('Logout').waitFor();
    await page.getByText('Total Burials').waitFor();
    await page.getByText('Logout').click();
    await page.getByRole('textbox', { name: 'Email' }).waitFor();
    await page.waitForTimeout(500);

    await signIn(page, 'admin@demo.test', 'Admin123!');
    try {
      await page.getByText('Logout').waitFor({ timeout: 5000 });
    } catch (error) {
      console.error('After second login:', (await page.locator('body').innerText()).slice(0, 800));
      await page.screenshot({ path: '/tmp/admin-emulator-relogin-failure.png' });
      throw error;
    }
    await adminRole.update({ role: 'visitor' });
    await page.getByText('Administrator or staff access is required.').waitFor();
    assert.deepEqual(errors, []);
    console.log('Connected admin and limited staff login, visitor denial, logout, and live role revocation passed.');
  } finally {
    await adminRole.update({ role: 'admin' });
    await staffRole.update({ role: 'staff' });
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
