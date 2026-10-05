const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST ??= '127.0.0.1:8188';
admin.initializeApp({ projectId: 'demo-smart-cemetery' });

async function main() {
  const snapshot = await admin.firestore().collection('maintenance')
    .where('requestedBy', '==', 'demo-visitor').get();
  const request = snapshot.docs.find((doc) =>
    doc.get('description') === 'Connected emulator maintenance check.');
  if (!request) {
    throw new Error('Submit the connected mobile maintenance flow first.');
  }
  await request.ref.update({ status: 'In Progress', priority: 'High' });
  console.log(`Updated ${request.id} to In Progress / High.`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
