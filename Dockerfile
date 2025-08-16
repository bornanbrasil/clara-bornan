# =========================
# Stage 0: Node provider
# =========================
FROM node:23-alpine AS node

# =========================
# Stage 1: Pre-builder (compile gems + assets)
# =========================
FROM ruby:3.4.4-alpine3.21 AS pre-builder

ARG NODE_VERSION="23.7.0"
ARG PNPM_VERSION="10.2.0"
ENV NODE_VERSION=${NODE_VERSION}
ENV PNPM_VERSION=${PNPM_VERSION}

# Build-time defaults (pod will override via envFrom)
ARG BUNDLE_WITHOUT="development:test"
ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT}
ENV BUNDLER_VERSION=2.5.11
ARG RAILS_SERVE_STATIC_FILES=true
ENV RAILS_SERVE_STATIC_FILES=${RAILS_SERVE_STATIC_FILES}
ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ARG NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"
ENV NODE_OPTIONS=${NODE_OPTIONS}
ENV BUNDLE_PATH="/gems"

# Base packages for build (gems + native extensions + assets)
RUN apk update && apk add --no-cache \
  build-base \
  curl \
  git \
  g++ \
  gcc \
  linux-headers \
  make \
  musl \
  musl-dev \
  openssl \
  openssl-dev \
  postgresql-dev \
  postgresql-client \
  tar \
  tzdata \
  vips \
  xz \
  && gem install bundler -v ${BUNDLER_VERSION}

# Provide node/npm/npx from Stage 0 for asset build only
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
  && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
  && npm install -g pnpm@${PNPM_VERSION}

# PNPM env
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN mkdir -p "$PNPM_HOME" && pnpm --version

WORKDIR /app

# Gems primeiro (melhor cache)
COPY Gemfile Gemfile.lock ./
RUN bundle config set --local force_ruby_platform true \
  && if [ "$RAILS_ENV" = "production" ]; then \
       bundle config set without 'development test'; \
     fi \
  && bundle install -j 4 -r 3

# Node deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# App code
COPY . /app

# Diretório de logs (caso não use STDOUT)
RUN mkdir -p /app/log

# Precompile assets somente em produção; slimming após
RUN if [ "$RAILS_ENV" = "production" ]; then \
      SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled bundle exec rake assets:precompile && \
      rm -rf node_modules tmp/cache spec; \
    fi

# SHA do commit (injete com --build-arg GIT_SHA=$(git rev-parse HEAD))
ARG GIT_SHA=unknown
RUN echo "$GIT_SHA" > /app/.git_sha

# Limpeza de cache de gems / resíduos
RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
  && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete \
  && rm -rf .git .gitignore

# =========================
# Stage 2: Final runtime (slim, sem Node)
# =========================
FROM ruby:3.4.4-alpine3.21

ENV BUNDLER_VERSION=2.5.11
ARG RAILS_ENV=production
ENV RAILS_ENV=${RAILS_ENV}
ENV BUNDLE_PATH="/gems"
ENV EXECJS_RUNTIME=Disabled
ENV RAILS_SERVE_STATIC_FILES=true
ENV BUNDLE_FORCE_RUBY_PLATFORM=1

# Runtime packages ONLY
RUN apk update && apk add --no-cache \
  build-base \
  git \
  imagemagick \
  openssl \
  postgresql-client \
  tzdata \
  vips \
  && gem install bundler -v ${BUNDLER_VERSION}

# Copia gems e app do pre-builder
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app
COPY --from=pre-builder /app/.git_sha /app/.git_sha

# Permissões dos entrypoints
RUN chmod +x /app/docker/entrypoints/rails.sh \
             /app/docker/entrypoints/vite.sh || true

WORKDIR /app
EXPOSE 3000
