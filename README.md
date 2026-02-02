# Listmonk Helm Chart
[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/listmonk-chart)](https://artifacthub.io/packages/search?repo=listmonk-chart)

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

## Configuration

All options are in `values.yaml`. Main sections:

| Section | Purpose |
|--------|--------|
| `replicaCount`, `image` | Listmonk app replicas and image |
| `database` | DB host, port, name, user; use `listmonk-postgres` when embedded Postgres is enabled |
| `postgres` | Embedded Postgres: image, storage, resources, migration hook, PDB, `waitForDatabase` |
| `smtp` | SMTP secret from values; set `enabled: true` and fill host/port/credentials |
| `admin` | Admin username/password (used by init job) |
| `ingress` | Hosts, TLS, `className`; set `enabled: true` for external access |
| `resources`, `autoscaling` | CPU/memory; optional HPA |
| `podDisruptionBudget` | PDB for Listmonk pods (default `minAvailable: 0`) |
| `init` | DB init job: `enabled`, `runAsHook` (pre-install/pre-upgrade) |

Override with `--set` or a custom `values` file. See `values.yaml` for full options and comments.

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

## Comparison with other charts

| | This chart (redzumi/listmonk-chart) | Deliveryhero / community listmonk chart |
|--|--------------------------------------|----------------------------------------|
| **Install** | `helm install` only | Install script + `helm` + patches |
| **Database** | Embedded Postgres (StatefulSet) or external | Often external or custom Postgres |
| **SMTP** | Secret from values; configure in Admin UI | Manual or script-based |
| **Upgrades** | Pre-upgrade hook migrates StatefulSet when needed; idempotent init | Manual migration or broken upgrades |
| **Stability** | PDBs, DB wait init, startup probe, job timeouts | Varies |
| **Maintenance** | Standard Helm; single chart repo | Scripts + chart + docs in multiple places |

This chart aims for a single `helm install`/`helm upgrade` flow, no extra scripts, and safe upgrades with embedded Postgres.

## Troubleshooting

```bash
kubectl get pods -n listmonk -l app.kubernetes.io/name=listmonk
kubectl logs -n listmonk -l app.kubernetes.io/name=listmonk -f
kubectl logs -n listmonk job/<release-name>-init
```
