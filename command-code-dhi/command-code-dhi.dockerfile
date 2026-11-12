FROM dhi.io/node:22-debian12-dev

USER root

ARG COMMAND_CODE_VERSION=latest
ARG GH_VERSION
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      gzip \
      jq \
      less \
      procps \
      ripgrep \
      unzip \
 && rm -rf /var/lib/apt/lists/*

# The sandbox runtime installs its proxy CA here. The DHI image ships the
# directory tree without it, so the injection would fail silently and every
# TLS request would be rejected with an unknown authority.
RUN mkdir -p /usr/local/share/ca-certificates \
 && update-ca-certificates

# Additional command: GitHub CLI, from the official release tarball.
# BuildKit supplies TARGETARCH, so the same recipe builds for arm64 and amd64.
RUN case "$TARGETARCH" in \
      amd64) gharch=amd64 ;; \
      arm64) gharch=arm64 ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && mkdir -p /tmp/gh \
 && cd /tmp/gh \
 && base="https://github.com/cli/cli/releases/download/v${GH_VERSION}" \
 && asset="gh_${GH_VERSION}_linux_${gharch}.tar.gz" \
 && curl -fsSLO "${base}/${asset}" \
 && curl -fsSLO "${base}/gh_${GH_VERSION}_checksums.txt" \
 && grep " ${asset}\$" "gh_${GH_VERSION}_checksums.txt" | sha256sum -c - \
 && tar -xzf "${asset}" \
 && install -m 0755 "gh_${GH_VERSION}_linux_${gharch}/bin/gh" /usr/local/bin/gh \
 && rm -rf /tmp/gh \
 && gh --version

# The image ships uid 1000 as `node`; the sandbox runtime expects `agent`.
RUN userdel --remove node 2>/dev/null || true; \
    groupdel node 2>/dev/null || true; \
    groupadd --gid 1000 agent \
 && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash agent \
 && mkdir -p /home/agent/workspace /home/agent/.commandcode \
 && chown -R agent:agent /home/agent

RUN touch /etc/sandbox-persistent.sh \
 && chown agent:agent /etc/sandbox-persistent.sh \
 && chmod 0644 /etc/sandbox-persistent.sh \
 && printf '%s\n' '. /etc/sandbox-persistent.sh' \
      > /etc/profile.d/sandbox-persistent.sh \
 && printf '%s\n' '. /etc/sandbox-persistent.sh' \
      >> /home/agent/.bashrc

ENV HOME=/home/agent \
    BASH_ENV=/etc/sandbox-persistent.sh \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    NODE_OPTIONS=--disable-warning=UNDICI-EHPA \
    NPM_CONFIG_PREFIX=/home/agent/.npm-global \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    DO_NOT_TRACK=1 \
    PATH="/home/agent/.npm-global/bin:${PATH}"

# Stable path for the TUI, independent of the npm prefix.
RUN ln -sf /home/agent/.npm-global/bin/cmd /usr/local/bin/cmd

USER agent

RUN npm i -g --no-fund --no-audit "command-code@${COMMAND_CODE_VERSION}" \
 && npm cache clean --force \
 && cmd --version | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'

WORKDIR /home/agent/workspace

ENTRYPOINT ["cmd", "--yolo", "--trust", "--skip-onboarding", "--no-auto-update"]
CMD []
