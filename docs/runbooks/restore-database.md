# Restore the database from backup

Use this to recover `penny-db` after data loss, and monthly as a drill into a scratch namespace. An untested backup is a hope, not a backup.

**You need:** `kubectl` access to the cluster, the `cnpg` kubectl plugin, and the backup bucket credentials (in the password manager; the sealed copy in git cannot be read back).

## 1. Check the backups exist

```sh
kubectl get backups -n penny-dev
kubectl cnpg status penny-db -n penny-dev   # "Continuous Backup status" should show a recent archived WAL
```

If the last base backup or the WAL archive is old, stop and find out why before relying on it.

## 2. Restore into a new cluster

CloudNativePG restores by bootstrapping a **new** cluster from the object store; it never overwrites a running one. For a drill, use a scratch namespace:

```sh
kubectl create namespace penny-restore-drill
# Copy the backup credentials and the role secrets into the scratch namespace
# (from the password manager), then apply:
```

```yaml
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: penny-backups
  namespace: penny-restore-drill
spec:
  configuration:
    destinationPath: s3://penny-backups/dev/  # the environment being restored
    endpointURL: https://ACCOUNT_ID.r2.cloudflarestorage.com
    s3Credentials:
      accessKeyId: { name: penny-backup-s3, key: ACCESS_KEY_ID }
      secretAccessKey: { name: penny-backup-s3, key: ACCESS_SECRET_KEY }
---
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: penny-db-restored
  namespace: penny-restore-drill
spec:
  instances: 1
  imageName: ghcr.io/cloudnative-pg/postgis:18-3.7-standard-trixie
  storage: { storageClass: local-path, size: 5Gi }
  bootstrap:
    recovery:
      source: penny-db
      # For point-in-time recovery, uncomment and set a time before the incident:
      # recoveryTarget:
      #   targetTime: "2026-11-20 09:30:00+08"
  externalClusters:
    - name: penny-db  # the original cluster's name in the bucket
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: penny-backups
          serverName: penny-db
```

Watch it come up: `kubectl cnpg status penny-db-restored -n penny-restore-drill`.

## 3. Verify

```sh
kubectl cnpg psql penny-db-restored -n penny-restore-drill -- penny -c \
  "SELECT max(version_id) FROM goose_db_version WHERE is_applied;"
kubectl cnpg psql penny-db-restored -n penny-restore-drill -- penny -c \
  "SELECT count(*), max(created_at) FROM users;"
```

The migration version should match the running API's build, and the newest rows should be from just before the backup or the recovery target.

## 4a. After a drill

Record the date, the restore time and anything that went wrong in the drill log below, then `kubectl delete namespace penny-restore-drill`.

## 4b. After a real incident

1. Scale the API to zero so nothing writes to the damaged cluster: `kubectl scale deploy/penny-api -n penny-dev --replicas=0`.
2. Restore into the environment's namespace under a new name (as above, without the scratch namespace), and verify.
3. Point the API at the restored cluster: change `penny-db-rw` and `penny-db-ca` in `base/api/` to the new cluster's service and CA secret in a pull request, or rename by restoring a second time as `penny-db` once the old cluster is deleted.
4. Re-enable backups on the restored cluster (its `plugins` section, as in `base/database/cluster.yaml`) so the new timeline is archived.
5. Write up what happened.

## Drill log

| Date | Environment | Restore time | Notes |
| --- | --- | --- | --- |
| | | | First drill pending: the dev environment is not deployed yet |
