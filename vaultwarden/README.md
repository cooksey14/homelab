# Vaultwarden Helm Chart

A complete GitOps setup for Vaultwarden (Bitwarden-compatible server) using Helm and ArgoCD.

## Features

- ✅ **Complete Helm Chart** with all necessary templates
- ✅ **GitOps Deployment** via ArgoCD
- ✅ **TLS/HTTPS** with Let's Encrypt certificates
- ✅ **Persistent Storage** for data
- ✅ **Resource Limits** and security contexts
- ✅ **Production Ready** configuration

## Quick Start

### 1. Generate Admin Token

Before deploying, generate a secure admin token:

```bash
openssl rand -base64 48
```

### 2. Update Configuration

Edit `argocd-applications/vaultwarden.yaml` and replace:
- `CHANGE_ME_GENERATE_WITH_OPENSSL_RAND_BASE64_48` with your generated admin token
- `vaultwarden.cooklabs.net` with your domain (if different)

### 3. Deploy via ArgoCD

Apply the ArgoCD application:

```bash
kubectl apply -f argocd-applications/vaultwarden.yaml
```

### 4. Access Vaultwarden

- **Web Vault**: https://vaultwarden.cooklabs.net
- **Admin Panel**: https://vaultwarden.cooklabs.net/admin (use your admin token)

## Configuration

### Environment Variables

Key environment variables in `values.yaml`:

- `ADMIN_TOKEN`: Admin panel access token
- `DOMAIN`: Your domain for the web vault
- `SIGNUPS_ALLOWED`: Allow new user registrations
- `INVITATIONS_ALLOWED`: Allow invitations
- `PASSWORD_ITERATIONS`: PBKDF2 iterations (higher = more secure)
- `WEBSOCKET_ENABLED`: Enable WebSocket for real-time updates

### Security Settings

- **Password Iterations**: Set to 100,000 for better security
- **Signups**: Disable after initial setup (`SIGNUPS_ALLOWED: "false"`)
- **Admin Panel**: Access via `/admin` endpoint with admin token

### Storage

- **Persistent Volume**: 2Gi storage for user data
- **Database**: SQLite (file-based, suitable for single instance)

## Production Considerations

### Security

1. **Disable Signups**: Set `SIGNUPS_ALLOWED: "false"` after setup
2. **Strong Admin Token**: Use a long, random admin token
3. **Regular Backups**: Backup the persistent volume regularly
4. **Monitor Logs**: Check logs for any security issues

### Scaling

- **Single Instance**: Current setup is for single instance
- **High Availability**: For HA, consider external database (PostgreSQL/MySQL)
- **Load Balancing**: Multiple replicas with shared storage

### Backup

```bash
# Backup the data volume
kubectl exec -n vaultwarden deployment/vaultwarden -- tar czf /tmp/backup.tar.gz /data
kubectl cp vaultwarden/vaultwarden-pod:/tmp/backup.tar.gz ./vaultwarden-backup.tar.gz
```

## Troubleshooting

### Common Issues

1. **Admin Token Not Working**: Ensure token is properly generated and set
2. **TLS Issues**: Check cert-manager and Let's Encrypt configuration
3. **Storage Issues**: Verify PVC is bound and has sufficient space
4. **WebSocket Issues**: Ensure `WEBSOCKET_ENABLED: "true"`

### Logs

```bash
# Check Vaultwarden logs
kubectl logs -n vaultwarden deployment/vaultwarden

# Check ArgoCD sync status
kubectl describe application vaultwarden -n argocd
```

## File Structure

```
vaultwarden/
├── Chart.yaml              # Helm chart metadata
├── values.yaml             # Default values
└── templates/
    ├── _helpers.tpl        # Template helpers
    ├── deployment.yaml     # Vaultwarden deployment
    ├── service.yaml        # Service
    ├── ingress.yaml        # Ingress with TLS
    ├── pvc.yaml           # Persistent volume claim
    └── serviceaccount.yaml # Service account

argocd-applications/
└── vaultwarden.yaml       # ArgoCD application

namespaces/
└── vaultwarden.yaml       # Namespace definition
```

## Best Practices Implemented

- ✅ **GitOps**: All configuration in git
- ✅ **No Manual Patches**: Everything declarative
- ✅ **Security**: Non-root user, read-only filesystem where possible
- ✅ **Resource Management**: CPU/memory limits and requests
- ✅ **TLS**: Automatic certificate management
- ✅ **Persistence**: Data survives pod restarts
- ✅ **Monitoring**: Health checks and probes
