FROM node:22-bookworm-slim

ARG COMMAND_CODE_VERSION
ARG GH_VERSION
ARG TARGETARCH

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq less procps ripgrep unzip \
 && rm -rf /var/lib/apt/lists/*

# Additional command: GitHub CLI, pinned and checksum-verified. TARGETARCH
# (amd64 or arm64) matches the release asset names directly.
RUN asset="gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && base="https://github.com/cli/cli/releases/download/v${GH_VERSION}" \
 && curl -fsSLo /tmp/gh.tgz "${base}/${asset}" \
 && echo "$(curl -fsSL "${base}/gh_${GH_VERSION}_checksums.txt" | grep " ${asset}\$" | cut -d' ' -f1)  /tmp/gh.tgz" \
      | sha256sum -c - \
 && tar -xzf /tmp/gh.tgz -C /usr/local --strip-components=1 --wildcards '*/bin/gh' \
 && rm /tmp/gh.tgz \
 && gh --version

# Installed as root into /usr/local, so cmd is on PATH and the agent cannot
# modify its own binary. The cache mount keeps npm tarballs out of the image.
RUN --mount=type=cache,target=/root/.npm \
    npm i -g --no-fund --no-audit "command-code@${COMMAND_CODE_VERSION}" \
 && cmd --version

# The image ships uid 1000 as `node`; the sandbox runtime expects `agent`.
RUN usermod --login agent --home /home/agent --move-home node \
 && groupmod --new-name agent node \
 && mkdir -p /home/agent/workspace /home/agent/.commandcode \
 && chown -R agent:agent /home/agent \
 && install -o agent -g agent -m 0644 /dev/null /etc/sandbox-persistent.sh \
 && echo '. /etc/sandbox-persistent.sh' > /etc/profile.d/sandbox-persistent.sh \
 && echo '. /etc/sandbox-persistent.sh' >> /etc/bash.bashrc

# Every HTTPS request leaves through a TLS-terminating proxy whose CA sbx adds
# to the system store; Node reads only its own bundle unless told otherwise.
ENV BASH_ENV=/etc/sandbox-persistent.sh \
    NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt \
    NODE_OPTIONS=--disable-warning=UNDICI-EHPA \
    DO_NOT_TRACK=1

USER agent
WORKDIR /home/agent/workspace

ENTRYPOINT ["cmd", "--yolo", "--trust", "--skip-onboarding", "--no-auto-update"]
CMD []
