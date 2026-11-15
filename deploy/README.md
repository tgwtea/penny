# deploy

Kustomize manifests that ArgoCD syncs to the homelab K3s cluster: `base/` plus `overlays/dev` and `overlays/prod`. CI never applies these; ArgoCD pulls them.

Arrives in Phase 1. See `docs/architecture.md`, "Infrastructure and deployment".
