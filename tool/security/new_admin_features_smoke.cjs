const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { chromium } = require('playwright-core');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9098';
admin.initializeApp({ projectId: 'demo-smart-cemetery' });

const url = process.env.ADMIN_EMULATOR_URL || 'http://127.0.0.1:8087/';
const chrome = process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

async function fill(page, name, value, last = false) {
  const field = last
    ? page.getByRole('textbox', { name }).last()
    : page.getByRole('textbox', { name });
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
  const email = `staff-smoke-${Date.now()}@demo.test`;
  const browser = await chromium.launch({ executablePath: chrome, headless: true });
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    permissions: ['clipboard-read', 'clipboard-write'],
  });
  const page = await context.newPage();
  let createdUid;
  try {
    await page.goto(url);
    await fill(page, 'Email', 'admin@demo.test');
    await fill(page, 'Password', 'Admin123!');
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.getByText('Total Burials').waitFor();
    await page.getByText('User Management').first().click();
    await page.getByRole('button', { name: 'Create staff login' }).click();
    await fill(page, 'Name', 'Smoke Staff');
    await fill(page, 'Email', email, true);
    await page.getByRole('button', { name: 'Create', exact: true }).click();
    await page.getByText('Staff login created').waitFor({ timeout: 15000 });
    await page.getByRole('button', { name: 'Copy password' }).click();
    await page.waitForTimeout(250);
    const password = await page.evaluate(() => navigator.clipboard.readText());
    assert.ok(password.length >= 12, 'Temporary password was not copied');
    const user = await admin.auth().getUserByEmail(email);
    createdUid = user.uid;
    const profile = await admin.firestore().doc(`users/${createdUid}`).get();
    assert.equal(profile.data().role, 'staff');
    assert.equal(profile.data().name, 'Smoke Staff');
    await page.getByRole('button', { name: 'Done' }).click();
    await page.getByText('Logout').click();
    await page.getByRole('textbox', { name: 'Email' }).waitFor();
    await fill(page, 'Email', email);
    await fill(page, 'Password', password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.getByText('Grave Management').waitFor();
    assert.equal(await page.getByText('User Management').count(), 0);
    console.log('Staff login creation, password, sign-in, and role assignment passed.');
  } catch (error) {
    console.error((await page.locator('body').innerText()).slice(-1000));
    await page.screenshot({ path: '/tmp/smart-cemetery-admin-feature-failure.png' });
    throw error;
  } finally {
    if (!createdUid) {
      try {
        createdUid = (await admin.auth().getUserByEmail(email)).uid;
      } catch (error) {
        if (error.code !== 'auth/user-not-found') throw error;
      }
    }
    if (createdUid) {
      await admin.firestore().doc(`users/${createdUid}`).delete();
      await admin.auth().deleteUser(createdUid);
    }
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
