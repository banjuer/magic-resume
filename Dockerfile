# syntax=docker.io/docker/dockerfile:1

ARG ALPINE_MIRROR=""
ARG NPM_REGISTRY_MIRROR=""
ARG PNPM_REGISTRY_MIRROR=""

FROM node:20-alpine AS base
ARG ALPINE_MIRROR
ARG NPM_REGISTRY_MIRROR
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# 配置了镜像地址则使用镜像，否则走默认源
# Use mirror if configured, otherwise use default sources
RUN if [ -n "$ALPINE_MIRROR" ]; then \
      sed -i "s/dl-cdn.alpinelinux.org/${ALPINE_MIRROR}/g" /etc/apk/repositories; \
    fi
RUN if [ -n "$NPM_REGISTRY_MIRROR" ]; then \
      npm config set registry "${NPM_REGISTRY_MIRROR}"; \
    fi

RUN npm install -g corepack@latest && corepack enable
WORKDIR /app

FROM base AS deps
ARG PNPM_REGISTRY_MIRROR
COPY package.json pnpm-lock.yaml ./

RUN if [ -n "$PNPM_REGISTRY_MIRROR" ]; then \
      pnpm config set registry "${PNPM_REGISTRY_MIRROR}"; \
    fi

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

FROM deps AS builder
COPY . .
RUN pnpm run build && pnpm prune --prod

FROM base AS runner
ENV NODE_ENV=production
WORKDIR /app

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodeapp

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/server.mjs ./server.mjs

USER nodeapp

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

CMD ["node", "server.mjs"]
