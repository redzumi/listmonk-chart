# Listmonk Helm Chart

A production-ready Helm chart for deploying [Listmonk](https://listmonk.app) - a self-hosted newsletter and mailing list manager.

## Features

- ✅ Embedded PostgreSQL (no operator required)
- ✅ Optional SMTP secret generation from values
- ✅ Ingress with TLS (controller-agnostic)
- ✅ Health probes (liveness, readiness, startup) and resource limits
- ✅ Secure credential management with Kubernetes secrets
- ✅ Simple Helm-only install/uninstall
- ✅ Stability: PodDisruptionBudgets, DB wait init, Postgres readiness probe, job timeouts

## Prerequisites

- Kubernetes cluster
- Helm 3.x
- No external database required (embedded Postgres)
- SMTP credentials (Mailgun, SendGrid, etc.)

## Quick Start

### 1. Install the Chart
```bash
helm install listmonk . -n listmonk
```

## Configuration

All configuration is in `values.yaml`. Key sections:

### Database
```yaml
database:
  host: "listmonk-postgres"  # Keep this when using embedded postgres; set to your DB host if external
  port: 5432
  name: listmonk
  user: listmonk
  sslMode: disable
```

### Embedded Postgres
```yaml
postgres:
  enabled: true
  image:
    repository: "postgres"
    tag: "15"
  storage:
    size: 4Gi
    storageClass: ""  # Empty = cluster default
```

### SMTP
```yaml
smtp:
  enabled: false
  existingSecret: ""
  host: "smtp.example.com"
  port: 587
```

### Admin Credentials
```yaml
admin:
  username: admin
  password: "your-secure-password"
```

### Ingress
```yaml
ingress:
  enabled: false
  className: ""
  hosts:
    - host: example.com
      paths:
        - path: /
          pathType: Prefix
```

## How It Works

The chart creates an embedded Postgres StatefulSet, Listmonk deployment, and
supporting resources in one Helm install/upgrade.

**Stability:** PodDisruptionBudgets protect Postgres (and optionally Listmonk) during voluntary disruptions. When `postgres.waitForDatabase` is true (default), Listmonk pods wait for Postgres to accept connections before starting. A startup probe gives the app time to boot before liveness is enforced. Init and migration jobs use time limits and backoff so they don’t hang indefinitely.

### Manual SMTP Configuration

Due to Listmonk v6.0.0 changes, SMTP must be configured manually via the Admin UI:

1. Login to: https://example.com/admin
2. Go to: **Settings → SMTP**
3. Click "Add Server" and use credentials from `listmonk-smtp` secret:
   ```bash
   kubectl get secret -n listmonk listmonk-smtp -o jsonpath='{.data.smtp-host}' | base64 -d
   ```
4. Test the SMTP connection

**Why manual?** Listmonk v6.0.0 requires API users (not admin users) for programmatic API access. API users can only be created via the Admin UI, so automated SMTP config during installation isn't possible.

### Label Selectors

All resources use consistent labels:
```yaml
app.kubernetes.io/name: listmonk
app.kubernetes.io/instance: {{ .Release.Name }}
```

No label mismatch issues!

## Upgrading

```bash
helm upgrade listmonk . -n listmonk
```

The chart reconciles the Postgres StatefulSet and Listmonk deployment on each upgrade.

### ⚠️ IMPORTANT: StatefulSet name stability

**The StatefulSet name must remain stable** to preserve your database. If you set `nameOverride` or `fullnameOverride`, you **must** use the same values on every upgrade.

#### PVC naming pattern

PVCs created by the embedded Postgres StatefulSet are named:

`data-<statefulset-name>-<ordinal>`

The StatefulSet name is `<nameOverride or chart name>-postgres` (e.g. with defaults: `listmonk-postgres`), so the PVC is typically **`data-listmonk-postgres-0`**.

If the StatefulSet name changes (e.g. you change `nameOverride`), Kubernetes creates a **new** PVC and the old one is **orphaned**—your data remains on the old PVC but is no longer attached. See [Data recovery](#data-recovery) if this happens.

### From versions < 2.0.0

Due to changes in the PostgreSQL StatefulSet configuration, upgrades from chart versions before 2.0.0 are handled automatically by a pre-upgrade hook: it scales down the StatefulSet, deletes it with `--cascade=orphan` (so PVCs are preserved), and lets Helm recreate it with the new spec. Your data is safe—the PVC is reattached automatically.

**If the migration hook fails** (e.g. `BackoffLimitExceeded`): set `postgres.migration.enabled: false`, then run the manual steps below and retry the upgrade. Check the job logs with `kubectl logs -n <namespace> job/<release-name>-postgres-migration` to see why it failed.

If you prefer to migrate manually:

```bash
# Scale down the StatefulSet
kubectl scale statefulset <release-name>-postgres -n <namespace> --replicas=0

# Delete the StatefulSet (PVCs are preserved)
kubectl delete statefulset <release-name>-postgres -n <namespace> --cascade=orphan

# Now upgrade normally
helm upgrade <release-name> . --namespace <namespace>
```

Replace `<release-name>` with your Helm release name (e.g. `listmonk`) and `<namespace>` with your namespace.

## Uninstalling

```bash
helm uninstall listmonk -n listmonk
```

Helm will remove chart-managed resources. If you want a full purge (PVCs and
generated secrets), delete them manually after uninstall.

## Data recovery

If an upgrade created a new PVC and your data is on an **orphaned** PVC (e.g. you changed `nameOverride` or the StatefulSet was recreated with a different name):

1. **List PVCs** in the release namespace:
   ```bash
   kubectl get pvc -n <namespace>
   ```
   Identify the old PVC (e.g. `data-listmonk-postgres-0`) and any new one.

2. **Scale down** the Postgres StatefulSet and delete it so you can reattach the old PVC:
   ```bash
   kubectl scale statefulset <statefulset-name> -n <namespace> --replicas=0
   kubectl delete statefulset <statefulset-name> -n <namespace> --cascade=orphan
   ```

3. **Upgrade again** so Helm recreates the StatefulSet. The new StatefulSet will create a new PVC by default. To use the old PVC instead you must either:
   - Restore the previous `nameOverride` / naming so the StatefulSet name matches the orphaned PVC, then upgrade; or
   - Manually patch the new StatefulSet’s volume to use the existing PVC (advanced), or copy data from the old PVC into the new one.

4. **Safest approach**: Use the same `nameOverride` and `fullnameOverride` on every install and upgrade so the StatefulSet name never changes and the same PVC is always used.

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n listmonk -l app.kubernetes.io/name=listmonk
```

### View logs
```bash
kubectl logs -n listmonk -l app.kubernetes.io/name=listmonk
```

### Check init job
```bash
kubectl get jobs -n listmonk
kubectl logs -n listmonk job/listmonk-init
```

### Verify service endpoints
```bash
kubectl get endpoints -n listmonk listmonk
```

## Comparison with Old Approach

### Before (deliveryhero chart + scripts)
- ❌ Complex install script with patches
- ❌ Manual SMTP configuration
- ❌ Label mismatch issues
- ❌ Deployment left in broken state on failures
- ❌ Difficult to maintain

### Now (Custom chart)
- ✅ Simple `helm install` command
- ✅ Optional SMTP secret via values
- ✅ Consistent labels throughout
- ✅ Helm-native resource management
- ✅ Standard Helm patterns

## Publishing to Artifact Hub

Artifact Hub requires a **Helm repository URL** that serves `index.yaml` and chart `.tgz` files—not the raw GitHub source URL. This repo supports two ways to publish.

### Option A: GitHub Actions (recommended)

A workflow builds the Helm repo and deploys it to GitHub Pages on every push to `main`/`master`.

1. **Enable GitHub Pages from Actions**
   - Repo → **Settings** → **Pages**
   - **Build and deployment** → **Source**: **GitHub Actions**

2. **Push to `main` (or `master`)**  
   The [Publish Helm repo](.github/workflows/publish-helm-repo.yml) workflow runs, builds the chart and index, and deploys to Pages.

3. **Add the repository in Artifact Hub**
   - Go to [Artifact Hub](https://artifacthub.io) → **Repositories** → **Add**
   - **Kind**: Helm charts
   - **URL** (no trailing slash):
     ```
     https://<owner>.github.io/<repo>
     ```
     Example: `https://myuser.github.io/listmonk-chart`

4. **(Optional) Verified publisher**  
   After adding the repo, copy its **repository ID** from Artifact Hub, set it in `artifacthub-repo.yml` in the repo root, and push. The “Verified publisher” badge will appear after the next re-index.

**If Artifact Hub says “the url provided does not point to a valid Helm repository”:**

- **Use the deployed URL, not the GitHub repo URL.**  
  Correct: `https://<owner>.github.io/<repo>`  
  Wrong: `https://github.com/<owner>/<repo>`
- **Set Pages source to GitHub Actions.**  
  Repo → **Settings** → **Pages** → **Source**: **GitHub Actions** (not “Deploy from a branch”).
- **Run the workflow once.**  
  Push to `main`/`master` or **Actions** → **Publish Helm repo** → **Run workflow**. Wait until the workflow succeeds.
- **Confirm the repo is live.**  
  Open `https://<owner>.github.io/<repo>/index.yaml` in your browser. You should see YAML (chart index). If you see 404 or an HTML page, fix Pages/workflow first, then add the URL in Artifact Hub.

### Option B: Manual build and branch-based Pages

If you prefer to deploy from a branch and folder:

1. Build: `REPO_URL="https://<owner>.github.io/<repo>" ./scripts/build-repo.sh`
2. Commit and push the generated `docs/` contents.
3. In **Settings** → **Pages**, set **Source** to **Deploy from a branch**, branch `main`, folder **/docs**.
4. Add the same URL in Artifact Hub as above.

## Values Reference

See `values.yaml` for all available options with inline documentation.
