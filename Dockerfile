# syntax=docker/dockerfile:1

ARG ZIG_VERSION=0.16.0

FROM debian:bookworm-slim AS builder

ARG ZIG_VERSION
ARG TARGETARCH
ARG BUILDARCH

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Zig for the *build* host; it cross-compiles to TARGETARCH-linux-musl.
RUN set -eux; \
    host_arch="${BUILDARCH:-$(uname -m)}"; \
    case "$host_arch" in \
        amd64|x86_64) host_arch=x86_64; sha=70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00 ;; \
        arm64|aarch64) host_arch=aarch64; sha=ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17 ;; \
        *) echo "unsupported BUILDARCH=$host_arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-${host_arch}-linux-${ZIG_VERSION}.tar.xz" \
        -o /tmp/zig.tar.xz; \
    echo "${sha}  /tmp/zig.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/zig.tar.xz -C /usr/local; \
    mv "/usr/local/zig-${host_arch}-linux-${ZIG_VERSION}" /usr/local/zig; \
    ln -sf /usr/local/zig/zig /usr/local/bin/zig; \
    rm -f /tmp/zig.tar.xz

WORKDIR /src

COPY build.zig build.zig.zon ./
RUN zig build --fetch

COPY src ./src
RUN set -eux; \
    target_arch="${TARGETARCH:-$(uname -m)}"; \
    case "$target_arch" in \
        amd64|x86_64) zig_target=x86_64-linux-musl ;; \
        arm64|aarch64) zig_target=aarch64-linux-musl ;; \
        *) echo "unsupported TARGETARCH=$target_arch" >&2; exit 1 ;; \
    esac; \
    zig build -Doptimize=ReleaseSafe -Dtarget="$zig_target"

FROM scratch
COPY --from=builder /src/zig-out/bin/authum /authum
EXPOSE 8080
ENTRYPOINT ["/authum"]
