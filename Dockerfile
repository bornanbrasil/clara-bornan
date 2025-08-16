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

ARG CW_EDITION=ce
ENV CW_EDITION=${CW_EDITION}

ARG BUNDLER_VERSION=2.5.11
ENV BUNDLER_VERSION=${BUNDLER_VERSION}

ENV BUNDLE_PATH="/gems"
ENV BUNDLE_WITHOUT="development:test"
ENV BUNDLE_FORCE_RUBY_PLATFORM=1
ENV RAILS_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=4096 --openssl-legacy-provider"

# Toolchain/headers + libs p/ compilar gems nativas
RUN apk update && apk add --no-cache \
  build-base \
  linux-headers \
  openssl openssl-dev \
  postgresql-dev \  # necessário APENAS no build para compilar a gem 'pg'
  tzdata \
  git \
  xz \
  vips

# Node somente no build (assets)
COPY --from=node /usr/local/bin/node /usr/local/bin/
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
 && npm install -g pnpm@${PNPM_VERSION}

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"
RUN mkdir -p "$PNPM_HOME" && pnpm --version

WORKDIR /app

# Gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v "$BUNDLER_VERSION" \
 && bundle config set deployment true \
 && bundle config set without 'development test' \
 && bundle config set path "$BUNDLE_PATH" \
 && bundle config set force_ruby_platform true \
 && bundle install --jobs 4 --retry 3

# Front-end deps
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

# Código
COPY . /app

# Logs dir (fallback)
RUN mkdir -p /app/log

# Precompile de assets em produção (SECRET_KEY_BASE dummy)
RUN SECRET_KEY_BASE=precompile_placeholder RAILS_LOG_TO_STDOUT=enabled \
    bundle exec rake assets:precompile \
 && rm -rf node_modules tmp/cache spec

# Metadata do commit
ARG GIT_SHA=unknown
RUN echo "$GIT_SHA" > /app/.git_sha

# Limpeza de caches de gems
RUN rm -rf /gems/ruby/3.4.0/cache/*.gem \
 && find /gems/ruby/3.4.0/gems/ \( -name "*.c" -o -name "*.o" \) -delete

# =========================
# Stage 2: Runtime (magra, sem Node)
# =========================
FROM ruby:3.4.4-alpine3.21

# Persistir edição no runtime
ARG CW_EDITION=ce
ENV CW_EDITION=${CW_EDITION}

# Ambiente/Bundle
ENV RAILS_ENV=production
ENV RACK_ENV=production
ENV BUNDLE_PATH="/gems"
ENV BUNDLE_WITHOUT="development:test"
ENV BUNDLE_DEPLOYMENT=1
ENV BUNDLE_FORCE_RUBY_PLATFORM=1
ENV RAILS_SERVE_STATIC_FILES=true
ENV EXECJS_RUNTIME=Disabled
ENV RAILS_LOG_TO_STDOUT=enabled

# Dependências de runtime mínimas:
RUN apk update && apk add --no-cache \
  tzdata \
  openssl \
  postgresql-libs \
  vips \
  libstdc++ \
  git \
  bash \
 && gem install bundler -v 2.5.11

# Copia do pre-builder
COPY --from=pre-builder /gems/ /gems/
COPY --from=pre-builder /app /app
COPY --from=pre-builder /app/.git_sha /app/.git_sha

WORKDIR /app
EXPOSE 3000

# Entrypoint
COPY docker/entrypoints/rails.sh /usr/local/bin/rails-entrypoint.sh
RUN chmod +x /usr/local/bin/rails-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/rails-entrypoint.sh"]
