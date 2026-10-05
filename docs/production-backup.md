# Production backup setup

The web admin's encrypted download and restore are for **local preview data only**. A connected Firebase project needs backup controls at the Google Cloud project level. Browser records omit some protected Firestore data and do not contain Storage image bytes, so a browser export is not a complete cloud backup.

Use the real Firebase project ID in every command. The `gcloud` default project on a workstation may be unrelated to Smart Cemetery. A project owner must enable billing before enabling managed Firestore backups. Check current pricing and IAM access in the [Firestore backup documentation](https://cloud.google.com/firestore/docs/backups).

## Firestore records

Review existing schedules before adding one:

```sh
gcloud firestore backups schedules list --project=YOUR_FIREBASE_PROJECT_ID --database='(default)'
```

If no daily schedule exists, create one with 14 days of retention:

```sh
gcloud firestore backups schedules create --project=YOUR_FIREBASE_PROJECT_ID --database='(default)' --recurrence=daily --retention=14d
```

Then verify that a completed backup appears after the first scheduled run:

```sh
gcloud firestore backups list --project=YOUR_FIREBASE_PROJECT_ID --format='table(name,database,state)'
```

Firestore's managed backup includes the database's collections, including `graveLocations`, which is not readable as a collection by web clients. Restoring a managed backup creates a **new database**; it does not overwrite the active `(default)` database. Plan and test how the app would be pointed at or migrated from that restored database before relying on recovery. See [Google's restore guidance](https://cloud.google.com/firestore/docs/backups).

## Memorial and maintenance photos

Firestore backup does not include Cloud Storage photo bytes. Check the actual Firebase Storage bucket name in the Firebase console. Review its soft delete policy and set a suitable retention period, for example 30 days, after reviewing storage cost:

```sh
gcloud storage buckets describe gs://YOUR_STORAGE_BUCKET --project=YOUR_FIREBASE_PROJECT_ID --format=json
gcloud storage buckets update gs://YOUR_STORAGE_BUCKET --project=YOUR_FIREBASE_PROJECT_ID --soft-delete-duration=30d
```

Soft delete helps recover deleted objects and buckets during the chosen window. It is separate from Firestore's backup schedule. See [Cloud Storage bucket protection](https://cloud.google.com/storage/docs/soft-delete).

For an independent photo copy, configure a recurring bucket-to-bucket job in [Storage Transfer Service](https://cloud.google.com/storage-transfer/docs/create-transfers) to a restricted backup bucket. Choose a retention policy for that destination and verify a photo can be recovered from it. Soft delete alone is a recovery window, not an independent copy.

## Authentication accounts

Firestore backup does not include Firebase Authentication accounts. Export those separately to a restricted location outside this repository with the [Firebase CLI `auth:export` command](https://firebase.google.com/docs/cli/auth):

```sh
tool/security/node_modules/.bin/firebase auth:export /SECURE_BACKUP_LOCATION/accounts.json --project=YOUR_FIREBASE_PROJECT_ID
```

Treat exported password hashes and salts as sensitive. The export is a manual action until the project owner schedules it through a privileged service. A recovery drill must cover account UIDs because payment reminders, visits, and role documents refer to them.

## Read-only status check

After setup, run the repository's read-only check with the actual project and bucket:

```sh
bash tool/operations/backup_status.sh YOUR_FIREBASE_PROJECT_ID YOUR_STORAGE_BUCKET
```

The check lists schedules, available backups, and the bucket's protection settings. It does not create or modify cloud resources. Confirm that a backup reaches a ready state and perform a restore drill to a separate database before treating the setup as verified.
