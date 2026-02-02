# Listmonk Helm Chart

Production-ready Helm chart for [Listmonk](https://listmonk.app) — self-hosted newsletter and mailing list manager.

## Features

- Embedded PostgreSQL (no operator)
- Optional SMTP secret from values; configure in Admin UI
- Ingress with TLS, health probes, PDBs, DB wait init
- Secure secrets; Helm-only install/upgrade

## Prerequisites

- Kubernetes cluster, Helm 3.x
- SMTP credentials (Mailgun, SendGrid, etc.) for sending mail

## Quick Start

```bash
helm install listmonk . -n listmonk
```

See `values.yaml` for all options. Main sections: `database`, `postgres`, `smtp`, `admin`, `ingress`.

## SMTP

Set `smtp.enabled: true` and your SMTP values; the chart creates a secret. In Listmonk, go to **Settings → SMTP** in the Admin UI and add the server using those credentials (e.g. from secret `listmonk-smtp`).

## Upgrading

```bash
helm upgrade listmonk . -n listmonk
```

- **StatefulSet name:** Do not change `nameOverride` or `fullnameOverride` after first install, or a new PVC will be created and your DB PVC orphaned. PVCs are named `data-<statefulset-name>-<ordinal>` (e.g. `data-listmonk-postgres-0`).
- **From chart &lt; 2.0.0:** A pre-upgrade hook migrates the Postgres StatefulSet (scale down, delete with `--cascade=orphan`, Helm recreates it). Data is preserved. If the hook fails, set `postgres.migration.enabled: false`, run the manual steps below, then retry the upgrade.
- **Manual migration (if needed):**
  ```bash
  kubectl scale statefulset <release-name>-postgres -n <namespace> --replicas=0
  kubectl delete statefulset <release-name>-postgres -n <namespace> --cascade=orphan
  helm upgrade <release-name> . -n <namespace>
  ```

## Data recovery

If you have an orphaned PVC (e.g. after changing `nameOverride`): list PVCs with `kubectl get pvc -n <namespace>`, then scale down and delete the StatefulSet with `--cascade=orphan`, and upgrade again. Use the same `nameOverride` so the new StatefulSet matches the existing PVC name, or see advanced recovery in the repo.

## Uninstalling

```bash
helm uninstall listmonk -n listmonk
```

Delete PVCs and secrets manually if you want a full purge.

## Troubleshooting

```bash
kubectl get pods -n listmonk -l app.kubernetes.io/name=listmonk
kubectl logs -n listmonk -l app.kubernetes.io/name=listmonk -f
kubectl logs -n listmonk job/<release-name>-init
```

## Publishing to Artifact Hub

Use a **Helm repo URL** (e.g. `https://<owner>.github.io/<repo>`) that serves `index.yaml` and chart `.tgz` — not the GitHub source URL.

- **Option A:** Enable GitHub Pages from **Actions**. Push to `main`; the workflow builds and deploys. Add the Pages URL in Artifact Hub.
- **Option B:** Run `REPO_URL="https://<owner>.github.io/<repo>" ./scripts/build-repo.sh`, commit `docs/`, set Pages to deploy from branch `main` folder `/docs`, then add that URL in Artifact Hub.

Ensure `https://<owner>.github.io/<repo>/index.yaml` returns YAML before adding the repo in Artifact Hub.
