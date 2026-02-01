# Listmonk Helm Chart

A production-ready Helm chart for deploying [Listmonk](https://listmonk.app) - a self-hosted newsletter and mailing list manager.

## Features

- ✅ Embedded PostgreSQL (no operator required)
- ✅ Optional SMTP secret generation from values
- ✅ Ingress with TLS (controller-agnostic)
- ✅ Health probes and resource limits
- ✅ Secure credential management with Kubernetes secrets
- ✅ Simple Helm-only install/uninstall

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

The chart reconciles the Postgres CR and Listmonk deployment on each upgrade.

## Uninstalling

```bash
helm uninstall listmonk -n listmonk
```

Helm will remove chart-managed resources. If you want a full purge (PVCs and
generated secrets), delete them manually after uninstall.

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

## Values Reference

See `values.yaml` for all available options with inline documentation.
