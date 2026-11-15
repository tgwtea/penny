# Firebase Auth emulator for local development and CI.
# The Auth emulator runs on Node alone; no Java runtime is needed.
FROM node:24-alpine

ARG FIREBASE_TOOLS_VERSION=15.36.0

ENV NO_UPDATE_NOTIFIER=1 \
    FIREBASE_CLI_DISABLE_UPDATE_CHECK=true

RUN npm install --global "firebase-tools@${FIREBASE_TOOLS_VERSION}" \
    && npm cache clean --force

USER node
WORKDIR /home/node/firebase

# Download the emulator UI at build time so container start needs no network.
RUN firebase setup:emulators:ui

COPY --chown=node:node firebase.json .firebaserc ./

EXPOSE 9099 4000

CMD ["firebase", "emulators:start", "--only", "auth", "--project", "demo-penny"]
