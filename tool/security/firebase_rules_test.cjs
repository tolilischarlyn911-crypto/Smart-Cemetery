const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  runTransaction,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require('firebase/firestore');

async function main() {
  const env = await initializeTestEnvironment({
    projectId: 'demo-smart-cemetery',
    firestore: {
      host: '127.0.0.1',
      port: 8288,
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8',
      ),
    },
    storage: {
      host: '127.0.0.1',
      port: 9298,
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../storage.rules'),
        'utf8',
      ),
    },
  });
  try {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, 'users/admin'), { role: 'admin', name: 'Admin' });
      await setDoc(doc(db, 'users/visitor'), { role: 'visitor', name: 'Visitor' });
      await setDoc(doc(db, 'users/staff'), { role: 'staff', name: 'Staff' });
      await setDoc(doc(db, 'users/other'), { role: 'visitor', name: 'Other' });
      await setDoc(doc(db, 'users/stranger'), { role: 'visitor', name: 'Stranger' });
      await setDoc(doc(db, 'graveLocations/fixture-key'), { graveId: 'grave-1' });
      await setDoc(doc(db, 'graves/grave-1'), {
        name: 'Memorial', status: 'occupied', locationKey: 'fixture-key',
      });
      await setDoc(doc(db, 'announcements/security-test-welcome'), { title: 'Welcome' });
      await setDoc(doc(db, 'settings/cemetery'), { phone: '123' });
      await setDoc(doc(db, 'maintenance/request-1'), { requestedBy: 'visitor' });
      await setDoc(doc(db, 'payments/payment-1'), { ownerId: 'visitor' });
      await setDoc(doc(db, 'leases/lease-1'), { graveId: 'grave-1' });
    });

    const anonymous = env.unauthenticatedContext().firestore();
    const visitor = env.authenticatedContext('visitor').firestore();
    const staff = env.authenticatedContext('staff').firestore();
    const other = env.authenticatedContext('other').firestore();
    const admin = env.authenticatedContext('admin').firestore();
    const newUser = env.authenticatedContext('new-user').firestore();

    for (const path of ['graves/grave-1', 'announcements/security-test-welcome', 'settings/cemetery']) {
      await assertFails(getDoc(doc(anonymous, path)));
      await assertSucceeds(getDoc(doc(visitor, path)));
    }
    await assertFails(getDoc(doc(anonymous, 'users/admin')));
    await assertFails(getDoc(doc(visitor, 'users/admin')));
    await assertSucceeds(getDoc(doc(visitor, 'users/visitor')));
    await assertSucceeds(getDocs(collection(admin, 'users')));
    await assertFails(getDocs(collection(visitor, 'users')));
    await assertFails(getDocs(collection(staff, 'users')));

    await assertFails(updateDoc(doc(visitor, 'users/visitor'), { role: 'admin' }));
    await assertFails(setDoc(doc(visitor, 'users/fake-admin'), { role: 'admin' }));
    await assertFails(setDoc(doc(newUser, 'users/new-user'), { role: 'admin' }));
    await assertFails(setDoc(doc(newUser, 'users/new-staff'), { role: 'staff' }));
    await assertSucceeds(setDoc(doc(newUser, 'users/new-user'), { role: 'visitor' }));
    await assertFails(updateDoc(doc(admin, 'users/admin'), { role: 'visitor' }));
    await assertSucceeds(updateDoc(doc(admin, 'users/other'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(admin, 'users/other'), { role: 'staff' }));
    await assertFails(updateDoc(doc(other, 'users/staff'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(admin, 'users/other'), { role: 'admin' }));
    assert.equal((await getDoc(doc(other, 'users/other'))).data().role, 'admin');

    await assertFails(updateDoc(doc(visitor, 'graves/grave-1'), { status: 'available' }));
    await assertFails(setDoc(doc(admin, 'graves/claimless'), {
      status: 'available', locationKey: 'new-key',
    }));
    await assertFails(getDoc(doc(visitor, 'graveLocations/fixture-key')));
    await assertSucceeds(getDoc(doc(admin, 'graveLocations/fixture-key')));
    await assertFails(updateDoc(doc(admin, 'graveLocations/fixture-key'), {
      graveId: 'another-grave',
    }));
    await assertFails(deleteDoc(doc(admin, 'graveLocations/fixture-key')));
    const claimedGrave = writeBatch(admin);
    claimedGrave.set(doc(admin, 'graveLocations/new-key'), { graveId: 'claimed' });
    claimedGrave.set(doc(admin, 'graves/claimed'), {
      status: 'available', locationKey: 'new-key',
    });
    await assertSucceeds(claimedGrave.commit());
    await assertFails(setDoc(doc(admin, 'graves/conflict'), {
      status: 'available', locationKey: 'new-key',
    }));
    const race = await Promise.allSettled(['race-a', 'race-b'].map((id) =>
      runTransaction(admin, async (transaction) => {
        const claimRef = doc(admin, 'graveLocations/race-key');
        const claim = await transaction.get(claimRef);
        if (claim.exists()) throw new Error('Plot already claimed.');
        transaction.set(claimRef, { graveId: id });
        transaction.set(doc(admin, `graves/${id}`), {
          id, status: 'available', locationKey: 'race-key',
        });
      }),
    ));
    assert.equal(race.filter((result) => result.status === 'fulfilled').length, 1);
    assert.equal(race.filter((result) => result.status === 'rejected').length, 1);
    const winner = (await getDoc(doc(admin, 'graveLocations/race-key'))).data().graveId;
    assert.ok(winner === 'race-a' || winner === 'race-b');
    assert.equal((await getDoc(doc(admin, `graves/${winner}`))).data().locationKey, 'race-key');
    await assertSucceeds(updateDoc(doc(staff, 'graves/grave-1'), { status: 'available' }));
    await assertSucceeds(updateDoc(doc(admin, 'graves/grave-1'), { status: 'reserved' }));
    await assertFails(getDoc(doc(visitor, 'leases/lease-1')));
    await assertFails(getDoc(doc(staff, 'leases/lease-1')));
    await assertSucceeds(getDoc(doc(admin, 'leases/lease-1')));

    await assertSucceeds(getDoc(doc(visitor, 'maintenance/request-1')));
    await assertSucceeds(getDocs(collection(staff, 'maintenance')));
    await assertFails(getDoc(doc(anonymous, 'maintenance/request-1')));
    await assertFails(setDoc(doc(visitor, 'maintenance/spoofed'), { requestedBy: 'stranger' }));
    await assertSucceeds(setDoc(doc(visitor, 'maintenance/new'), { requestedBy: 'visitor' }));
    await assertFails(updateDoc(doc(visitor, 'maintenance/request-1'), { status: 'Completed' }));
    await assertSucceeds(updateDoc(doc(staff, 'maintenance/request-1'), { status: 'Completed' }));
    await assertFails(updateDoc(doc(staff, 'maintenance/request-1'), { requestedBy: 'staff' }));
    await assertSucceeds(updateDoc(doc(admin, 'maintenance/request-1'), {
      status: 'In Progress',
      priority: 'High',
    }));
    await assertSucceeds(getDocs(query(
      collection(visitor, 'maintenance'),
      where('requestedBy', '==', 'visitor'),
    )));
    await assertFails(getDocs(collection(visitor, 'maintenance')));
    await assertSucceeds(getDoc(doc(visitor, 'payments/payment-1')));
    await assertFails(getDoc(doc(staff, 'payments/payment-1')));
    await assertFails(getDocs(collection(staff, 'payments')));
    await assertFails(getDoc(doc(anonymous, 'payments/payment-1')));
    await assertFails(getDocs(collection(visitor, 'payments')));
    await assertSucceeds(getDocs(query(
      collection(visitor, 'payments'),
      where('ownerId', '==', 'visitor'),
    )));

    const bucket = 'gs://demo-smart-cemetery.appspot.com';
    const adminStorage = env.authenticatedContext('admin').storage(bucket);
    const visitorStorage = env.authenticatedContext('visitor').storage(bucket);
    const staffStorage = env.authenticatedContext('staff').storage(bucket);
    const strangerStorage = env.authenticatedContext('stranger').storage(bucket);
    const anonymousStorage = env.unauthenticatedContext().storage(bucket);
    const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]);
    const metadata = { contentType: 'image/png' };

    await assertFails(visitorStorage.ref('grave-photos/grave-1/tomb').put(png, metadata));
    await assertSucceeds(adminStorage.ref('grave-photos/grave-1/tomb').put(png, metadata));
    await assertSucceeds(staffStorage.ref('grave-photos/grave-1/staff-tomb').put(png, metadata));
    await assertFails(anonymousStorage.ref('grave-photos/grave-1/tomb').getMetadata());
    await assertSucceeds(visitorStorage.ref('grave-photos/grave-1/tomb').getMetadata());

    await assertSucceeds(visitorStorage.ref('maintenance/visitor/request-1').put(png, metadata));
    await assertFails(strangerStorage.ref('maintenance/visitor/request-1').getMetadata());
    await assertSucceeds(adminStorage.ref('maintenance/visitor/request-1').getMetadata());
    await assertSucceeds(staffStorage.ref('maintenance/visitor/request-1').getMetadata());
    await assertFails(strangerStorage.ref('profiles/visitor/avatar').put(png, metadata));
    await assertSucceeds(visitorStorage.ref('profiles/visitor/avatar').put(png, metadata));
    console.log('Firestore and Storage role and visitor access rules passed.');
  } finally {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      for (const path of [
        'users/admin', 'users/visitor', 'users/staff', 'users/other',
        'users/stranger', 'users/new-user', 'graves/grave-1',
        'graveLocations/fixture-key', 'graveLocations/new-key', 'graves/claimed',
        'graveLocations/race-key', 'graves/race-a', 'graves/race-b',
        'announcements/security-test-welcome', 'settings/cemetery',
        'maintenance/request-1', 'maintenance/new', 'payments/payment-1',
        'leases/lease-1',
      ]) {
        await deleteDoc(doc(db, path));
      }
    });
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
