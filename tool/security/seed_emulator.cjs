const admin = require('firebase-admin');
const { createHash } = require('node:crypto');

const projectId = 'demo-smart-cemetery';
process.env.FIREBASE_AUTH_EMULATOR_HOST ??= '127.0.0.1:9098';
process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
admin.initializeApp({ projectId });

function locationKeyFor(block, lot, number) {
  return createHash('sha256')
    .update([block, lot, number].join('\0'))
    .digest('hex');
}

async function ensureUser(uid, email, password, role, name) {
  try {
    await admin.auth().getUser(uid);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    await admin.auth().createUser({ uid, email, password, displayName: name });
  }
  await admin.firestore().doc(`users/${uid}`).set({ email, name, role });
}

async function main() {
  await ensureUser(
    'demo-admin',
    'admin@demo.test',
    'Admin123!',
    'admin',
    'Demo Administrator',
  );
  await ensureUser(
    'demo-visitor',
    'visitor@demo.test',
    'Visitor123!',
    'visitor',
    'Demo Visitor',
  );
  await ensureUser(
    'demo-staff',
    'staff@demo.test',
    'Staff123!',
    'staff',
    'Demo Staff',
  );
  const db = admin.firestore();
  const locationKey = locationKeyFor('12', '45', '3');
  await db.doc(`graveLocations/${locationKey}`).set({ graveId: 'pedro-dela-cruz' });
  await db.doc('graves/pedro-dela-cruz').set({
    id: 'pedro-dela-cruz',
    locationKey,
    name: 'Pedro Dela Cruz',
    block: '12',
    lot: '45',
    number: '3',
    status: 'occupied',
    mapRow: 2,
    mapColumn: 2,
    born: '1940-05-12T00:00:00.000',
    died: '2020-03-03T00:00:00.000',
    buriedAt: '2020-03-05T00:00:00.000',
    birthplace: 'Manila, Philippines',
    deathplace: 'Quezon City, Philippines',
    message: 'Always in our hearts.',
    photos: [],
    portraitPhotoUrl: 'assets/images/portrait_sample.png',
    tombPhotoUrl: 'assets/images/grave_sample.png',
    latitude: 14.6327,
    longitude: 120.9897,
  });
  const now = new Date();
  const plotBatch = db.batch();
  let sampleIndex = 0;
  for (let row = 0; row < 4; row++) {
    for (let col = 0; col < 5; col++) {
      if (row === 2 && col === 2) continue;
      const lot = String(row * 5 + col + 1);
      const id = `sample-plot-${lot.padStart(2, '0')}`;
      const key = locationKeyFor('12', lot, '1');
      const occupied = sampleIndex < 12;
      const buriedAt = occupied
        ? new Date(now.getFullYear(), now.getMonth() - sampleIndex - 1, 12).toISOString()
        : null;
      plotBatch.set(db.doc(`graveLocations/${key}`), { graveId: id });
      plotBatch.set(db.doc(`graves/${id}`), {
        id,
        locationKey: key,
        name: occupied ? `Demo Memorial ${String(sampleIndex + 1).padStart(2, '0')}` : '',
        block: '12',
        lot,
        number: '1',
        status: occupied ? 'occupied' : (row + col) % 3 === 0 ? 'reserved' : 'available',
        mapRow: row,
        mapColumn: col,
        born: null,
        died: null,
        buriedAt,
        birthplace: '',
        deathplace: '',
        message: occupied ? 'Illustrative memorial for the connected demo.' : '',
        photos: [],
        portraitPhotoUrl: null,
        tombPhotoUrl: occupied ? 'assets/images/grave_sample.png' : null,
        latitude: 14.6330 - row * 0.00015,
        longitude: 120.9893 + col * 0.00015,
      });
      sampleIndex++;
    }
  }
  await plotBatch.commit();
  await db.doc('settings/general').set({
    visitingHours: 'Demo hours: 8:00 AM–5:00 PM',
    guidelines: 'Demo data only. Replace with cemetery rules.',
    emergencyContact: '0000000000',
    mapCenterLatitude: 14.6327,
    mapCenterLongitude: 120.9897,
  });
  await db.doc('announcements/welcome').set({
    id: 'welcome',
    title: 'Welcome to the connected demo',
    body: 'This data is stored in local Firebase emulators.',
    date: new Date().toISOString(),
  });
  const due = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000);
  await db.doc('payments/demo-annual-fee').set({
    id: 'demo-annual-fee',
    payer: 'Demo Visitor',
    graveId: 'pedro-dela-cruz',
    type: 'Annual Fee',
    amount: 1500,
    date: now.toISOString(),
    dueDate: due.toISOString(),
    ownerId: 'demo-visitor',
    status: 'Pending',
  });
  await db.doc('payments/demo-paid-fee').set({
    id: 'demo-paid-fee',
    payer: 'Demo Staff',
    graveId: 'sample-plot-01',
    type: 'Annual Fee',
    amount: 1500,
    date: new Date(now.getTime() - 10 * 24 * 60 * 60 * 1000).toISOString(),
    dueDate: new Date(now.getTime() - 20 * 24 * 60 * 60 * 1000).toISOString(),
    ownerId: 'demo-staff',
    status: 'Paid',
  });
  await db.doc('leases/demo-lease').set({
    id: 'demo-lease',
    graveId: 'pedro-dela-cruz',
    lessee: 'Demo Visitor',
    ownerId: 'demo-visitor',
    startsAt: now.toISOString(),
    endsAt: new Date(now.getTime() + 365 * 24 * 60 * 60 * 1000).toISOString(),
    status: 'Active',
  });
  await db.doc('maintenance/demo-request').set({
    id: 'demo-request',
    graveId: 'pedro-dela-cruz',
    issue: 'Damaged Tombstone',
    description: 'Connected emulator maintenance check.',
    requestedBy: 'demo-visitor',
    createdAt: now.toISOString(),
    status: 'In Progress',
    priority: 'High',
    photoUrl: null,
  });
  await db.doc('maintenance/demo-pending-request').set({
    id: 'demo-pending-request',
    graveId: 'sample-plot-02',
    issue: 'Overgrown grass',
    description: 'Illustrative request for the connected demo.',
    requestedBy: 'demo-staff',
    createdAt: new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000).toISOString(),
    status: 'Pending',
    priority: 'Medium',
    photoUrl: null,
  });
  console.log('Seeded demo accounts, 20 graves and plots, settings, announcement, payments, lease, and requests.');
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
