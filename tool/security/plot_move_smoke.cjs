const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const admin = require('firebase-admin');
const { chromium } = require('playwright-core');

const url = process.env.ADMIN_EMULATOR_URL || 'http://127.0.0.1:8087/';
const chrome = process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
admin.initializeApp({ projectId: 'demo-smart-cemetery' });
const db = admin.firestore();
const id = 'qa-plot-move';
const oldBlock = 'QA-MOVE-20261005';
const newBlock = 'QA-MOVED-20261005';
const key = (block) => createHash('sha256')
  .update([block.toLowerCase(), '1', '1'].join('\0')).digest('hex');

async function fill(page, name, value) {
  const field = page.getByRole('textbox', { name, exact: true });
  for (let attempt = 0; attempt < 4; attempt++) {
    await field.click();
    await page.waitForTimeout(150);
    await field.fill(value);
    await page.waitForTimeout(150);
    if (await field.inputValue() === value) return;
  }
  throw new Error(`${name} did not retain input.`);
}

async function main() {
  let browser;
  let page;
  try {
    await db.doc(`graveLocations/${key(oldBlock)}`).set({ graveId: id });
    await db.doc(`graves/${id}`).set({
      id,
      locationKey: key(oldBlock),
      block: oldBlock,
      lot: '1',
      number: '1',
      name: '',
      status: 'available',
      mapRow: 9,
      mapColumn: 0,
    });

    browser = await chromium.launch({ executablePath: chrome, headless: true });
    page = await browser.newPage({ viewport: { width: 1440, height: 900 } });
    const errors = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.goto(url);
    await fill(page, 'Email', 'admin@demo.test');
    await fill(page, 'Password', 'Admin123!');
    await page.getByText('Sign in', { exact: true }).click();
    await page.getByText('Grave Management', { exact: true }).first().click();
    await fill(page, 'Search name or location', oldBlock);
    await page.getByRole('button', { name: 'Edit grave record' }).click();
    await fill(page, 'Block', newBlock);
    await page.getByText('Save', { exact: true }).last().click();
    await page.getByText('Edit grave record').waitFor({ state: 'hidden', timeout: 12000 });

    const grave = (await db.doc(`graves/${id}`).get()).data();
    const oldClaim = await db.doc(`graveLocations/${key(oldBlock)}`).get();
    const newClaim = await db.doc(`graveLocations/${key(newBlock)}`).get();
    assert.equal(grave.block, newBlock);
    assert.equal(grave.locationKey, key(newBlock));
    assert.equal(oldClaim.exists, false);
    assert.equal(newClaim.data()?.graveId, id);
    assert.deepEqual(errors, []);
    console.log('Connected browser moved the grave and its plot claim atomically.');
  } catch (error) {
    if (page) await page.screenshot({ path: '/tmp/smart-cemetery-plot-move-failure.png' });
    throw error;
  } finally {
    if (browser) await browser.close();
    const batch = db.batch();
    batch.delete(db.doc(`graves/${id}`));
    batch.delete(db.doc(`graveLocations/${key(oldBlock)}`));
    batch.delete(db.doc(`graveLocations/${key(newBlock)}`));
    await batch.commit();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
