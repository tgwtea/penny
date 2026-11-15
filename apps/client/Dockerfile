# The web client: Flutter's web build served by unprivileged nginx.
# Build from the repository root, because the app depends on packages/:
#
#   docker build -f apps/client/Dockerfile -t penny-web .
#
# The image is built once and promoted between environments, so it carries
# no environment: at start, nginx writes /config.json from PENNY_API_URL and
# the app reads it (apps/client/lib/app/config.dart).
#
# Stages:
#   sdk      Flutter on Linux at the version pinned in .mise.toml. Also the
#            image `task test:goldens` renders golden images in.
#   build    the release web build
#   runtime  nginx serving it

FROM --platform=$BUILDPLATFORM debian:trixie-slim AS sdk

# Bump both together with .mise.toml. The checksum is in
# https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json
ARG FLUTTER_VERSION=3.50.0
ARG FLUTTER_SHA256=6ea2d806fd57269ae783e6788e2a81fc26eaad782f1e0d0ff38623bb765ff9f5

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl --fail --silent --show-error --location --output /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check - \
    && tar --extract --xz --file /tmp/flutter.tar.xz --directory /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --system --add safe.directory '*'

ENV PATH=/opt/flutter/bin:$PATH \
    PUB_CACHE=/opt/pub-cache \
    FLUTTER_SUPPRESS_ANALYTICS=true \
    CI=true

# Golden tests run as the caller's user so the files they write stay
# theirs; the SDK and pub cache are writable by any user for that reason.
RUN mkdir -p "${PUB_CACHE}" \
    && flutter config --no-analytics --no-cli-animations \
    && flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos \
    && chmod -R a+w /opt/flutter "${PUB_CACHE}" \
    && flutter --version

WORKDIR /src


FROM sdk AS build

# Dependencies first, so source edits do not invalidate this layer.
COPY packages/penny_ui/pubspec.yaml packages/penny_ui/
COPY packages/penny_api/pubspec.yaml packages/penny_api/
COPY apps/client/pubspec.yaml apps/client/pubspec.lock apps/client/
RUN cd apps/client && flutter pub get --enforce-lockfile

COPY packages packages
COPY apps/client apps/client

ARG VERSION=dev
# --no-web-resources-cdn: CanvasKit is served from this image, so browsers
# never fetch code from Google's CDN at run time.
RUN cd apps/client \
    && flutter build web --release --no-web-resources-cdn \
         --dart-define=PENNY_BACKEND=http \
         --build-name="${VERSION%%[-+]*}" \
    && echo "${VERSION}" > build/web/version.txt


FROM nginxinc/nginx-unprivileged:1.31.7-alpine AS runtime

# Where the app finds the API. Set per environment (deploy/base/web).
ENV PENNY_API_URL=""

COPY apps/client/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/apps/client/build/web /usr/share/nginx/html

EXPOSE 8080
