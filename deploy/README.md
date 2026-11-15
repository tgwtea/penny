# deploy

Kustomize manifests that ArgoCD syncs to the homelab K3s cluster (ADR 013). CI never applies these; it only commits new image digests, and ArgoCD pulls.

```text
argocd/penny-dev.yaml     the ArgoCD Application for dev (applied once by hand)
base/                     everything Penny runs, environment-neutral
  api/                    API Deployment, Service, PDB, migrate Job
  database/               CloudNativePG Cluster, off-site ObjectStore, daily backup
  ingress/                Traefik IngressRoute for the API host
  web/                    the web client: nginx Deployment, Service, IngressRoute
  tunnel/                 cloudflared, the outbound-only path from Cloudflare
  network/                default-deny ingress plus one allow per real path
  monitoring/             ServiceMonitor, PodMonitor, Grafana dashboard
overlays/dev/             namespace penny-dev: hostnames, backup path, secrets, digests
```

`task lint:deploy` renders every overlay and validates it against the Kubernetes schemas and the CRD catalog, so a typo in a CloudNativePG or Traefik field fails CI.

## How a change reaches dev

1. A pull request merges to `main`.
2. `release.yml` builds the changed images (linux/amd64 and linux/arm64), scans them, and commits their digests to `overlays/dev/kustomization.yaml`.
3. ArgoCD sees the commit and syncs `penny-dev` in waves:
   - wave -1: the database `Cluster` and its `ObjectStore`
   - wave 0: the `penny-migrate` Job (a Sync hook; a failure stops the sync)
   - wave 1: the API Deployment, rolled one pod at a time behind `/readyz`
   - the web client has no wave: it is static files and depends only on the API being reachable

The migrate Job is a Sync hook rather than the PreSync hook the architecture describes: PreSync runs before anything is created, so on the very first sync the database would not exist yet. Waves give the same guarantee: new API pods start only after migrations succeed.

## Cluster prerequisites

Installed once per cluster, outside this repository:

| Component | Why | Assumed location |
| --- | --- | --- |
| ArgoCD | pulls this directory | `argocd` namespace |
| CloudNativePG operator (1.30 or later) | runs `penny-db` | `cnpg-system` namespace |
| Barman Cloud plugin for CloudNativePG | WAL archiving and base backups | `cnpg-system` namespace |
| Sealed Secrets controller | decrypts `overlays/*/secrets/` | `kube-system` namespace |
| Prometheus Operator (kube-prometheus-stack) and Grafana with the dashboard sidecar | `ServiceMonitor`, `PodMonitor`, dashboard ConfigMap | `monitoring` namespace |
| Traefik | ingress; the K3s default | `kube-system` namespace |
| `local-path` storage class | database volumes; the K3s default | |

The network policies in `base/network/policies.yaml` name these namespaces. If the cluster differs, change them there.

## Before the first sync of an environment

These depend on open questions in `docs/architecture.md` and cannot be committed yet:

1. **Domain.** The overlay uses the reserved `penny.invalid` domain. Replace it in `overlays/dev/kustomization.yaml` (both IngressRoute hosts, the API's CORS origin, the web client's `PENNY_API_URL`) and `overlays/dev/cloudflared.yaml`.
2. **Tunnel.** `cloudflared tunnel create penny-dev`, put the tunnel ID in `overlays/dev/cloudflared.yaml`, seal the credentials file (below) and add a DNS CNAME for each hostname to `<tunnel-id>.cfargotunnel.com`.
3. **Backup bucket.** Create the bucket and an access key limited to it. Set the endpoint and path in the overlay's `ObjectStore` patch.
4. **Secrets.** Replace every placeholder in `overlays/dev/secrets/`.
5. **Prometheus selector.** If Prometheus only picks up monitors with a label (kube-prometheus-stack uses `release: <name>`), add it in the overlay.
6. Apply the Application: `kubectl apply -n argocd -f deploy/argocd/penny-dev.yaml`.

## Secrets

Secrets live in git only as SealedSecrets, encrypted to the cluster's Sealed Secrets key. The files in `overlays/dev/secrets/` are placeholders that cannot be decrypted; replace each with real output:

```sh
# Database roles: basic-auth secrets whose username is the role name.
kubectl create secret generic penny-migrator-db -n penny-dev --type=kubernetes.io/basic-auth \
  --from-literal=username=penny_migrator --from-literal=password="$(openssl rand -base64 32)" \
  --dry-run=client -o yaml | kubeseal -o yaml > deploy/overlays/dev/secrets/penny-migrator-db.yaml

kubectl create secret generic penny-app-db -n penny-dev --type=kubernetes.io/basic-auth \
  --from-literal=username=penny_app --from-literal=password="$(openssl rand -base64 32)" \
  --dry-run=client -o yaml | kubeseal -o yaml > deploy/overlays/dev/secrets/penny-app-db.yaml

# Off-site backups.
kubectl create secret generic penny-backup-s3 -n penny-dev \
  --from-literal=ACCESS_KEY_ID=... --from-literal=ACCESS_SECRET_KEY=... \
  --dry-run=client -o yaml | kubeseal -o yaml > deploy/overlays/dev/secrets/penny-backup-s3.yaml

# Cloudflare Tunnel credentials from `cloudflared tunnel create`.
kubectl create secret generic cloudflared-credentials -n penny-dev \
  --from-file=credentials.json=$HOME/.cloudflared/<tunnel-id>.json \
  --dry-run=client -o yaml | kubeseal -o yaml > deploy/overlays/dev/secrets/cloudflared-credentials.yaml
```

Store the plain values in the team's password manager as well: a sealed secret cannot be read back, and the backup credentials are needed to restore into a new cluster.

## Database roles

| Role | Rights | Used by |
| --- | --- | --- |
| `penny_migrator` | owns the `penny` database and every table | the migrate Job only |
| `penny_app` | `SELECT`, `INSERT`, `UPDATE`, `DELETE` on tables the migrator creates (default privileges) | the API and, later, the worker |

The bootstrap SQL in `base/database/cluster.yaml` creates PostGIS, `btree_gist` and `citext` as a superuser, since PostGIS is not a trusted extension, and sets the default privileges. Tables that must be append-only for the app (the audit log) revoke `UPDATE` and `DELETE` in their own migration.

## Release automation

`release.yml` pushes the digest commit with a GitHub App token, because `main` requires pull requests. Set up once:

1. Create a GitHub App with *Contents: read and write* on this repository and install it.
2. Add it to the `main` ruleset's bypass list.
3. Save its ID as the repository variable `PENNY_RELEASE_APP_ID` and a private key as the secret `PENNY_RELEASE_APP_PRIVATE_KEY`.

## Backups and restore

Continuous WAL archiving and a daily base backup (03:00 Singapore time) go to the off-site bucket, retained for 30 days. Restoring is a runbook: [`docs/runbooks/restore-database.md`](../docs/runbooks/restore-database.md). Drill it monthly into a scratch namespace.
