# Web app (Flutter), served by the server at /
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY app ./
RUN flutter build web --release --no-web-resources-cdn \
 && sh tool/finish_web_build.sh

# Server (Rust)
FROM rust:1-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock* ./
COPY migrations migrations
COPY src src
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --uid 10001 --home /data nestling \
    && mkdir -p /data && chown nestling /data
COPY --from=build /src/target/release/nestling /usr/local/bin/nestling
COPY --from=web /app/build/web /web
USER nestling
ENV NESTLING_DATABASE_URL=sqlite:///data/nestling.db \
    NESTLING_BIND=0.0.0.0:8080 \
    NESTLING_WEB_DIR=/web
VOLUME /data
EXPOSE 8080
CMD ["nestling"]
