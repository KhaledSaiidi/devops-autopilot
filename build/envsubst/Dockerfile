ARG DEBIAN_VERSION=bookworm
FROM debian:${DEBIAN_VERSION}-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN set -euo pipefail; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates gettext-base bash; \
    rm -rf /var/lib/apt/lists/*

RUN install -m 0555 /usr/bin/envsubst /envsubst

ENTRYPOINT ["/envsubst"]


# cd ~/devops-autopilot
# docker buildx create --use --name envsubst-builder 2>/dev/null
# docker buildx use envsubst-builder

# docker buildx build \
#   --platform linux/amd64,linux/arm64,linux/arm/v7 \
#   -t khaledsaiidi/envsubst-helper:1.4.2 \
#   -f build/envsubst/Dockerfile \
#   --push .
