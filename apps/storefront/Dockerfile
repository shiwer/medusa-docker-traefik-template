# ---------- base ----------
ARG NODE_VERSION=22.14
FROM node:${NODE_VERSION}-bookworm-slim AS base

# ---------- deps ----------
FROM base AS deps
WORKDIR /opt/storefront/deps
ARG NODE_ENV=development
ENV NODE_ENV=$NODE_ENV

# Install dependencies
COPY package*.json yarn.lock* pnpm-lock.yaml* .yarn* ./
RUN \
  if [ -f yarn.lock ]; then corepack enable && corepack prepare yarn@4.9.1 --activate && yarn install --immutable; \
  elif [ -f package-lock.json ]; then npm ci; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install; \
  else echo "Lockfile not found." && exit 1; \
  fi

# ---------- builder ----------
FROM base AS builder
WORKDIR /opt/storefront/build
ARG NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY
ARG NODE_ENV=production
ARG NEXT_PUBLIC_AUTH_CORS
ENV NODE_ENV=$NODE_ENV
ENV NEXT_PUBLIC_AUTH_CORS=${NEXT_PUBLIC_AUTH_CORS}

# Build the application
COPY --from=deps /opt/storefront/deps .
COPY . .
COPY --from=deps /opt/storefront/deps/*.lock ./
RUN \
  if [ -f yarn.lock ]; then corepack enable && corepack prepare yarn@4.9.1 --activate && yarn build; \
  elif [ -f package-lock.json ]; then npm run build; \
  elif [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm run build; \
  fi

# ---------- runner ----------
FROM base AS runner
RUN apt-get update \
  && apt-get install --no-install-recommends -y \
    curl \
    ca-certificates \
    tini \
    && apt-get clean \
  && rm -rf /var/lib/apt/lists/*  /tmp/* /var/tmp/*

USER node
WORKDIR /opt/storefront

COPY --from=builder --chown=node:node /opt/storefront/build/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=node:node /opt/storefront/build/.next/standalone ./
COPY --from=builder --chown=node:node /opt/storefront/build/.next/static ./.next/static

ARG NODE_ENV=production
ARG PORT=8000
ARG NEXT_PUBLIC_AUTH_CORS
ENV PORT=$PORT
ENV NODE_ENV=$NODE_ENV
ENV NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY=$NEXT_PUBLIC_MEDUSA_PUBLISHABLE_KEY
ENV NEXT_PUBLIC_AUTH_CORS=${NEXT_PUBLIC_AUTH_CORS}

EXPOSE $PORT


ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
