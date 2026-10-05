#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'Usage: %s FIREBASE_PROJECT_ID STORAGE_BUCKET_NAME\n' "$0" >&2
  exit 2
fi

project_id=$1
storage_bucket=$2

if [[ ! $project_id =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]] ||
   [[ $project_id == demo-* ]] ||
   [[ ! $storage_bucket =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  printf 'Use an explicit production project ID and bucket name.\n' >&2
  exit 2
fi

printf 'Firestore backup schedules for %s:\n' "$project_id"
gcloud firestore backups schedules list \
  --project="$project_id" \
  --database='(default)' \
  --format='table(name,recurrence,retention)'

printf '\nAvailable Firestore backups for %s:\n' "$project_id"
gcloud firestore backups list \
  --project="$project_id" \
  --format='table(name,database,state)'

printf '\nStorage bucket protection for gs://%s:\n' "$storage_bucket"
gcloud storage buckets describe "gs://$storage_bucket" \
  --project="$project_id" \
  --format=json
