ARG postgresql_major=17
ARG postgresql_release=${postgresql_major}.2

ARG pgx_ulid_release=0.2.0
ARG pg_search_release=0.14.1
ARG pg_analytics_release=0.3.0
ARG timescale_release=2.17.2

####################
# Postgres
####################
FROM postgres:${postgresql_release} as base

# Redeclare args for use in subsequent stages
ARG TARGETARCH
ARG postgresql_major

####################
# Extension: pgx_ulid
####################
FROM base as pgx_ulid

# Download package archive
ARG pgx_ulid_release
ADD "https://github.com/pksunkara/pgx_ulid/releases/download/v${pgx_ulid_release}/pgx_ulid-v${pgx_ulid_release}-pg${postgresql_major}-${TARGETARCH}-linux-gnu.deb" \
    /tmp/pgx_ulid.deb

####################
# Extension: pg_search
####################
FROM base as pg_search

# Download package archive
ARG pg_search_release
ADD "https://github.com/paradedb/paradedb/releases/download/v${pg_search_release}/postgresql-${postgresql_major}-pg-search_${pg_search_release}-1PARADEDB-bookworm_${TARGETARCH}.deb" \
    /tmp/pg_search.deb

####################
# Extension: pg_analytics
####################
FROM base as pg_analytics

# Download package archive
ARG pg_analytics_release
ADD "https://github.com/paradedb/pg_analytics/releases/download/v${pg_analytics_release}/postgresql-${postgresql_major}-pg-analytics_${pg_analytics_release}-1PARADEDB-bookworm_${TARGETARCH}.deb" \
    /tmp/pg_analytics.deb

####################
# Collect extension packages
####################
FROM scratch as extensions
COPY --from=pgx_ulid /tmp/*.deb /tmp/
COPY --from=pg_search /tmp/*.deb /tmp/
COPY --from=pg_analytics /tmp/*.deb /tmp/

####################
# Build final image
####################
FROM base as production

# Install necessary tools for building and compiling
RUN apt-get update && apt-get install -y \
    wget \
    build-essential \
    libtool \
    autoconf \
    unzip \
    ca-certificates

# Download and install ICU 74 manually from source
WORKDIR /tmp
RUN wget https://github.com/unicode-org/icu/releases/download/release-74-1/icu4c-74_1-src.tgz \
    && tar -xvzf icu4c-74_1-src.tgz \
    && cd icu/source \
    && ./configure --prefix=/usr/local \
    && make \
    && make install

# Set the LD_LIBRARY_PATH to include /usr/local/lib where ICU libraries are installed
ENV LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"

# Symlink the ICU libraries to a directory PostgreSQL can access
RUN ln -s /usr/local/lib/libicuuc.so.74 /usr/lib/libicuuc.so.74 \
    && ln -s /usr/local/lib/libicudata.so.74 /usr/lib/libicudata.so.74 \
    && ln -s /usr/local/lib/libicui18n.so.74 /usr/lib/libicui18n.so.74

# Install necessary tools for building and compiling
RUN apt-get install -y \
    git \
    cmake \
    gnupg \
    postgresql-common \
    apt-transport-https \
    lsb-release \
    postgresql-server-dev-${postgresql_major}

# Download and install Timescale manually from source
RUN git clone https://github.com/timescale/timescaledb \
    && cd timescaledb \
    && git checkout ${timescale_release} \
    && ./bootstrap \
    && cd build \
    && make \
    && make install

# Clean up
RUN rm -rf /tmp/* && apt-get clean && rm -rf /var/lib/apt/lists/*

# Setup extensions
COPY --from=extensions /tmp /tmp

RUN apt-get update && apt-get install -y --no-install-recommends \
    /tmp/*.deb \
    && rm -rf /var/lib/apt/lists/* /tmp/*

