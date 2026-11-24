FROM node:24-slim AS build

ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN corepack enable && corepack prepare pnpm@10 --activate

WORKDIR /app
COPY . .

RUN pnpm install --frozen-lockfile \
    && pnpm --filter @noname/fs build \
    && pnpm --filter @noname/server build \
    && pnpm build

FROM node:24-slim AS runtime

ENV HOST="0.0.0.0"

WORKDIR /app

COPY --from=build /app/packages/fs/node_modules ./packages/fs/node_modules
COPY --from=build /app/packages/fs/dist ./packages/fs/dist
COPY --from=build /app/packages/server/node_modules ./packages/server/node_modules
COPY --from=build /app/packages/server/dist ./packages/server/dist
COPY --from=build /app/dist ./dist

WORKDIR /app/dist

RUN groupadd --system --gid 10001 appuser \
    && useradd --system --uid 10001 --gid appuser --create-home appuser \
    && chown -R appuser:appuser /app/dist

USER appuser

EXPOSE 8080 8089

# 同时启动联机服务（8080）与静态文件服务（8089）
CMD ["sh", "-c", "node /app/packages/server/dist/cli.js --port 8080 & node /app/packages/fs/dist/entry.cjs --server"]
