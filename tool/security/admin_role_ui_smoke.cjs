const assert = require('node:assert/strict');
const admin = require('firebase-admin');
const { chromium } = require('playwright-core');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
admin.initializeApp({ projectId: 'demo-smart-cemetery' });

const url = process.env.ADMIN_EMULATOR_URL || 'http://127.0.0.1:8087/';
const chrome = process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const visitorRef = admin.firestore().doc('users/demo-visitor');

async function selectRole(page, currentRole, nextRole) {
  const control = page.getByRole('button', {
    name: `Change account role Demo Visitor visitor@demo.test Role: ${currentRole}`,
  });
  const box = await control.boundingBox();
  assert.ok(box, 'Visitor role control is visible');
  const x = box.x + box.width - 45;
  const y = box.y + box.height / 2;
  await page.mouse.click(x, y);
  await page.getByText('Dismiss menu').waitFor();
  await page.waitForTimeout(300);
  // Flutter paints this popup on its canvas; the menu entries do not have
  // separate web semantics nodes. Click relative to the role control.
  await page.mouse.click(x - 90, y + (nextRole === 'Staff' ? 64 : 14));
  await page.getByText(
    nextRole === 'Staff'
      ? 'Grant staff access?'
      : 'Change account to visitor?',
  ).waitFor();
  await page.getByText('CONFIRM').click();
  await page.getByRole('button', {
    name: `Change account role Demo Visitor visitor@demo.test Role: ${nextRole}`,
  }).waitFor();
}

async function main() {
  assert.equal((await visitorRef.get()).data()?.role, 'visitor');
  const browser = await chromium.launch({ executablePath: chrome, headless: true });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    await page.goto(url);
    for (const [name, value] of [
      ['Email', 'admin@demo.test'],
      ['Password', 'Admin123!'],
    ]) {
      const field = page.getByRole('textbox', { name });
      await field.waitFor();
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
    await page.getByText('Total Burials').waitFor();
    await page.getByText('User Management').first().click();
    const search = page.getByRole('textbox', { name: 'Search accounts' });
    await search.click();
    await search.pressSequentially('visitor@demo.test', { delay: 20 });
    await page.getByRole('button', {
      name: 'Change account role Demo Visitor visitor@demo.test Role: Visitor',
    }).waitFor();
    assert.equal(await page.getByText('Role: Visitor').count(), 1);

    await selectRole(page, 'Visitor', 'Staff');
    assert.equal((await visitorRef.get()).data()?.role, 'staff');
    await selectRole(page, 'Staff', 'Visitor');
    assert.equal((await visitorRef.get()).data()?.role, 'visitor');
    console.log('Connected admin role search, promotion, and revocation passed.');
  } finally {
    await visitorRef.update({ role: 'visitor' });
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
