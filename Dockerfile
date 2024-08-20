FROM node:18-slim AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN corepack enable

FROM base AS build
COPY . /usr/src/app
WORKDIR /usr/src/app

RUN apt-get update && apt-get install -y python3 make g++ git && rm -rf /var/lib/apt/lists/*

# Install dependencies
RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

# Deploy only the alvi-paas app

ENV NODE_ENV=production
RUN pnpm --filter=./apps/alvi-paas run build
RUN pnpm --filter=./apps/alvi-paas --prod deploy /prod/alvi-paas

RUN cp -R /usr/src/app/apps/alvi-paas/.next /prod/alvi-paas/.next
RUN cp -R /usr/src/app/apps/alvi-paas/dist /prod/alvi-paas/dist

FROM base AS alvi-paas
WORKDIR /app

# Set production
ENV NODE_ENV=production

RUN apt-get update && apt-get install -y curl apache2-utils && rm -rf /var/lib/apt/lists/*

# Copy only the necessary files
COPY --from=build /prod/alvi-paas/.next ./.next
COPY --from=build /prod/alvi-paas/dist ./dist
COPY --from=build /prod/alvi-paas/next.config.mjs ./next.config.mjs
COPY --from=build /prod/alvi-paas/public ./public
COPY --from=build /prod/alvi-paas/package.json ./package.json
COPY --from=build /prod/alvi-paas/drizzle ./drizzle
COPY .env.production ./.env
COPY --from=build /prod/alvi-paas/components.json ./components.json
COPY --from=build /prod/alvi-paas/node_modules ./node_modules


# Install docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh && rm get-docker.sh

# Install Nixpacks and tsx
# | VERBOSE=1 VERSION=1.21.0 bash
RUN curl -sSL https://nixpacks.com/install.sh -o install.sh \
    && chmod +x install.sh \
    && ./install.sh \
    && pnpm install -g tsx

# Install buildpacks
COPY --from=buildpacksio/pack:0.35.0 /usr/local/bin/pack /usr/local/bin/pack

EXPOSE 3000
CMD [ "pnpm", "start" ]
