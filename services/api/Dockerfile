# One image with both binaries, so the migrate Job and the API Deployment
# always run the same build. Build from this directory:
#
#   docker build --build-arg VERSION=0.1.0 --build-arg COMMIT=$(git rev-parse --short HEAD) .
#
# The Go version matches .mise.toml; Renovate keeps both current.
#
# The build stage runs on the builder's own platform and cross-compiles, so
# multi-platform images (linux/amd64 and linux/arm64) need no emulation.

FROM --platform=$BUILDPLATFORM golang:1.27.4-trixie AS build
WORKDIR /src

# Download modules first so source edits do not invalidate this layer.
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
ARG VERSION=dev
ARG COMMIT=unknown
ARG TARGETOS
ARG TARGETARCH
ENV CGO_ENABLED=0 GOFLAGS=-trimpath
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build \
      -ldflags "-s -w \
        -X github.com/tgwtea/penny/services/api/internal/platform/buildinfo.version=${VERSION} \
        -X github.com/tgwtea/penny/services/api/internal/platform/buildinfo.commit=${COMMIT}" \
      -o /out/ ./cmd/api ./cmd/migrate ./cmd/worker

# Distroless static: no shell, no package manager, runs as an unprivileged user.
FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /out/api /out/migrate /out/worker /usr/local/bin/
USER nonroot:nonroot
EXPOSE 8080 9090
ENTRYPOINT ["/usr/local/bin/api"]
