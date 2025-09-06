
# GitOps Workflow for ArgoCD Applications

This document describes the proper GitOps workflow for managing ArgoCD applications without manual `kubectl patch` commands.

## 🎯 **GitOps Principles**

1. **Git as Single Source of Truth**: All configurations are stored in Git
2. **Automatic Synchronization**: ArgoCD automatically syncs changes from Git
3. **Declarative Configuration**: All changes are made through Git commits
4. **No Manual Interventions**: No `kubectl patch` or manual sync commands

## 🔄 **Workflow Process**

### **Step 1: Make Changes in Git**
```bash
# 1. Edit application files locally
vim argocd-applications/mealie.yaml

# 2. Commit changes
git add argocd-applications/mealie.yaml
git commit -m "Update mealie application configuration"

# 3. Push to GitHub
git push origin main
```

### **Step 2: ArgoCD Automatically Syncs**
- ArgoCD detects changes in the Git repository
- Applications automatically sync within 3 minutes (default refresh interval)
- No manual intervention required

### **Step 3: Monitor in ArgoCD UI**
- Visit `https://argocd.cooklabs.net`
- Check application status
- View sync history and logs

## ⚙️ **Configuration Changes**

### **Enable/Disable Automatic Sync**
```yaml
# In argocd-applications/*.yaml
syncPolicy:
  automated:
    prune: true      # Automatically remove resources not in Git
    selfHeal: true   # Automatically fix drift
```

### **Update Application Values**
```yaml
# In argocd-applications/*.yaml
source:
  helm:
    values: |
      # Your Helm values here
      replicaCount: 3
      resources:
        limits:
          memory: "512Mi"
```

### **Change Application Source**
```yaml
# In argocd-applications/*.yaml
source:
  repoURL: https://github.com/your-org/your-repo.git
  path: your-app
  targetRevision: HEAD
```

## 🚀 **Application of Applications Pattern**

We use a "root application" that manages all other applications:

```yaml
# argocd-applications/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  source:
    repoURL: https://github.com/cooksey14/homelab.git
    path: argocd-applications  # Points to this directory
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 📋 **Best Practices**

### **1. Always Use Git Commits**
❌ **Don't do this:**
```bash
kubectl patch application mealie -n argocd --type merge -p '{"spec":{"source":{"helm":{"values":"..."}}}}'
```

✅ **Do this instead:**
```bash
# Edit the YAML file
vim argocd-applications/mealie.yaml
git add argocd-applications/mealie.yaml
git commit -m "Update mealie configuration"
git push
```

### **2. Use Descriptive Commit Messages**
```bash
git commit -m "Add resource limits to mealie application"
git commit -m "Enable automatic sync for monitoring application"
git commit -m "Update vaultwarden ingress configuration"
```

### **3. Test Changes Locally First**
```bash
# Validate Helm templates
helm template mealie ./mealie --values values.yaml

# Check YAML syntax
yamllint argocd-applications/*.yaml
```

### **4. Monitor Application Health**
- Check ArgoCD UI regularly
- Set up alerts for failed syncs
- Review sync logs for issues

## 🔧 **Troubleshooting**

### **Application Not Syncing**
1. Check Git repository access
2. Verify GitHub token is valid
3. Check ArgoCD application logs
4. Ensure target revision exists

### **Sync Failures**
1. Check resource conflicts
2. Verify Helm chart syntax
3. Check resource quotas
4. Review sync policies

### **Manual Sync (Emergency Only)**
```bash
# Only use in emergencies when GitOps is broken
kubectl patch application mealie -n argocd --type merge -p '{"operation":{"sync":{"syncStrategy":{"hook":{"force":true}}}}}'
```

## 📊 **Monitoring GitOps Health**

### **ArgoCD CLI Commands**
```bash
# List all applications
argocd app list

# Get application status
argocd app get mealie

# Sync application (emergency only)
argocd app sync mealie
```

### **Kubectl Commands**
```bash
# Check application status
kubectl get applications -n argocd

# View application details
kubectl describe application mealie -n argocd
```

## 🎉 **Benefits of GitOps**

1. **Audit Trail**: All changes are tracked in Git history
2. **Rollback Capability**: Easy to revert changes
3. **Collaboration**: Multiple people can review changes
4. **Automation**: No manual intervention required
5. **Consistency**: Same process for all environments
6. **Security**: Changes go through Git review process

## 📝 **Summary**

- ✅ **Make all changes in Git**
- ✅ **Use descriptive commit messages**
- ✅ **Let ArgoCD handle automatic sync**
- ✅ **Monitor application health**
- ❌ **Avoid manual kubectl patches**
- ❌ **Don't bypass Git workflow**
