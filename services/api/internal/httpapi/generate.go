package httpapi

// The contract is the source of truth (ADR 003). `task gen` runs this.
//go:generate go tool oapi-codegen -config oapi-codegen.yaml ../../../../api/openapi.yaml
