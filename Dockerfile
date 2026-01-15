# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?name=ubuntu
# https://hub.docker.com/_/ubuntu/tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian/tags?name=trixie-20251229-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: docker.io/hexpm/elixir:1.19.2-erlang-27.3.4-debian-trixie-20251229-slim
#
ARG ELIXIR_VERSION=1.19.2
ARG OTP_VERSION=27.3.4
ARG DEBIAN_VERSION=trixie-20251229-slim

ARG BUILDER_IMAGE="docker.io/hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="docker.io/debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies (including nodejs/npm for Tailwind plugins, curl for bun, unzip for bun)
RUN apt-get update \
  && apt-get install -y --no-install-recommends build-essential git nodejs npm curl unzip \
  && rm -rf /var/lib/apt/lists/*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force \
  && mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

RUN mix assets.setup

COPY priv priv

# Install Bun and OG image dependencies
RUN curl -fsSL https://bun.sh/install | bash \
  && /root/.bun/bin/bun install --cwd priv/bun-scripts
ENV PATH="/root/.bun/bin:${PATH}"

COPY lib lib

# Compile the release
RUN mix compile

COPY assets assets

# install npm dependencies for Tailwind plugins
RUN cd assets && npm install

# compile assets
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE} AS final

# Install runtime dependencies + sqlite3 for WAL mode setup + curl for Litestream + unzip for bun
RUN apt-get update \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates curl sqlite3 unzip \
  && rm -rf /var/lib/apt/lists/*

# Install Litestream for SQLite backups
ARG LITESTREAM_VERSION=0.3.13
RUN curl -L https://github.com/benbjohnson/litestream/releases/download/v${LITESTREAM_VERSION}/litestream-v${LITESTREAM_VERSION}-linux-amd64.deb -o /tmp/litestream.deb \
  && dpkg -i /tmp/litestream.deb \
  && rm /tmp/litestream.deb

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/ohio_elixir ./

# Copy Litestream configuration and entrypoint script
COPY --chown=nobody:root litestream.yml /etc/litestream.yml
COPY --chown=nobody:root run.sh /app/run.sh
RUN chmod +x /app/run.sh

# Create data directory for SQLite database (will be mounted as volume)
RUN mkdir -p /mnt/data && chown nobody:root /mnt/data

# Install Bun runtime for OG image generation (to /usr/local so nobody user can access)
ENV BUN_INSTALL="/usr/local"
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/usr/local/bin:${PATH}"

USER nobody

# Use custom entrypoint that handles Litestream restore/replication
ENTRYPOINT ["/app/run.sh"]
