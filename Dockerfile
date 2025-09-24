# syntax=docker/dockerfile:1
FROM ruby:3.2.4-slim-bookworm

# Frozen Debian snapshot for reproducible builds (bump when you want newer packages)
ARG DEBIAN_SNAPSHOT=20250830T000000Z
ENV DEBIAN_FRONTEND=noninteractive

# Replace ALL apt sources with a single snapshot (deb822), harden apt, install build tools
RUN set -eux; \
  # Remove any existing sources (legacy and deb822)
  rm -f /etc/apt/sources.list; \
  rm -f /etc/apt/sources.list.d/*; \
  \
  # Create deb822 snapshot sources file without heredocs (avoid parser issues)
  mkdir -p /etc/apt/sources.list.d; \
  printf '%s\n' \
    'Types: deb' \
    "URIs: https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}" \
    'Suites: bookworm' \
    'Components: main contrib non-free non-free-firmware' \
    '' \
    'Types: deb' \
    "URIs: https://snapshot.debian.org/archive/debian/${DEBIAN_SNAPSHOT}" \
    'Suites: bookworm-updates' \
    'Components: main contrib non-free non-free-firmware' \
    '' \
    'Types: deb' \
    "URIs: https://snapshot.debian.org/archive/debian-security/${DEBIAN_SNAPSHOT}" \
    'Suites: bookworm-security' \
    'Components: main contrib non-free non-free-firmware' \
    > /etc/apt/sources.list.d/snapshot.sources; \
  \
  # APT tweaks for snapshots & flaky caches
  mkdir -p /etc/apt/apt.conf.d; \
  printf '%s\n' \
    'Acquire::Check-Valid-Until "false";' \
    'Acquire::Retries "5";' \
    'Acquire::http::No-Cache "true";' \
    'Acquire::http::Pipeline-Depth "0";' \
    > /etc/apt/apt.conf.d/99snapshot.conf; \
  \
  # Clean residual state, then update & install
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential; \
  apt-get clean; \
  rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*.deb

# App setup
WORKDIR /app

# Install gems
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs 4

# Copy app code
COPY . .

# Non-root user
RUN groupadd --system app && \
    useradd --system --create-home --gid app appuser && \
    chown -R appuser:app /app
USER appuser

# Rails port
EXPOSE 3000

# Use JSON-array CMD form (good with signals)
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
