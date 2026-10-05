const admin = require('firebase-admin');
const { createHash } = require('node:crypto');

const projectId = process.env.FIREBASE_PROJECT_ID;
if (!projectId) {
  throw new Error('Set FIREBASE_PROJECT_ID before checking plot locations.');
}

admin.initializeApp({ projectId });
const db = admin.firestore();
const apply = process.argv.includes('--apply');

function locationKey(data) {
  const parts = ['block', 'lot', 'number'].map((field) => {
    const value = data[field];
    if (typeof value !== 'string' || !value.trim()) {
      throw new Error(`Missing ${field} for a grave record.`);
    }
    return value.trim().replace(/\s+/g, ' ').toLowerCase();
  });
  return createHash('sha256').update(parts.join('\0')).digest('hex');
}

async function main() {
  const graves = await db.collection('graves').get();
  const claims = await db.collection('graveLocations').get();
  const claimOwners = new Map(claims.docs.map((doc) => [doc.id, doc.data().graveId]));
  const desired = new Map();
  const records = [];

  for (const doc of graves.docs) {
    const key = locationKey(doc.data());
    const duplicate = desired.get(key);
    if (duplicate && duplicate !== doc.id) {
      throw new Error(`Duplicate plot records: ${duplicate} and ${doc.id}.`);
    }
    const owner = claimOwners.get(key);
    if (owner && owner !== doc.id) {
      throw new Error(`Plot claim ${key} belongs to ${owner}, not ${doc.id}.`);
    }
    desired.set(key, doc.id);
    records.push({ id: doc.id, key });
  }

  for (const [key, owner] of claimOwners) {
    if (desired.get(key) !== owner) {
      throw new Error(`Stale plot claim ${key} belongs to ${owner}. Resolve it before backfilling.`);
    }
  }

  const missing = records.filter(({ id, key }) =>
    claimOwners.get(key) !== id ||
    graves.docs.find((doc) => doc.id === id).data().locationKey !== key,
  );
  console.log(`${graves.size} grave ${graves.size === 1 ? 'record' : 'records'} checked; ${missing.length} need a plot claim or key.`);
  if (!apply) {
    console.log('Dry run only. Pass --apply to write the missing keys and claims.');
    return;
  }

  for (const { id, key } of missing) {
    const graveRef = db.collection('graves').doc(id);
    const claimRef = db.collection('graveLocations').doc(key);
    await db.runTransaction(async (transaction) => {
      const grave = await transaction.get(graveRef);
      const claim = await transaction.get(claimRef);
      if (!grave.exists || locationKey(grave.data()) !== key) {
        throw new Error(`Grave ${id} changed during backfill; rerun the check.`);
      }
      if (claim.exists && claim.data().graveId !== id) {
        throw new Error(`Plot ${key} was claimed by ${claim.data().graveId}.`);
      }
      transaction.set(graveRef, { locationKey: key }, { merge: true });
      transaction.set(claimRef, { graveId: id });
    });
  }
  console.log(`Backfilled ${missing.length} grave records.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
