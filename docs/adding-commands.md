# Adding more commands

The `gh` install in both Dockerfiles is the template to copy:

```dockerfile
ARG TARGETARCH
RUN case "$TARGETARCH" in \
      amd64) gharch=amd64 ;; \
      arm64) gharch=arm64 ;; \
      *) echo "unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;; \
    esac \
 && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${gharch}.tar.gz" \
 && curl -fsSLO "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_checksums.txt" \
 && grep " gh_${GH_VERSION}_linux_${gharch}.tar.gz\$" "gh_${GH_VERSION}_checksums.txt" | sha256sum -c - \
 && tar -xzf "gh_${GH_VERSION}_linux_${gharch}.tar.gz" \
 && install -m 0755 "gh_${GH_VERSION}_linux_${gharch}/bin/gh" /usr/local/bin/gh
```

BuildKit only exposes `TARGETARCH` when the Dockerfile declares it with
`ARG TARGETARCH`. Without the declaration the variable is empty and the build
fails at the architecture check.

## Three parts to every new command

1. **Install it in the image.** Prefer a pinned release with a checksum over a
   package manager that resolves `latest` at build time. Declare every build
   argument in the descriptor with `buildArg:` so it can be overridden per
   sandbox.
2. **Allow its network destinations** in `network-policy@1`. A credential's
   inject domains must also appear in that allow list, or the kit fails
   validation.
3. **Declare its credential** if it needs one. Use a built-in service name when
   one exists (`github`, `anthropic`, `openai`, and others), or declare your own
   service and store it with `sbx secret set <name>`. Approve the binding on
   first create.

Keep tool-specific access rules in the kit, so they travel with the tool when it
is combined with another workload or published as a mixin.

## Notes from the gh implementation

- The release tarball ships a directory named after the archive; the binary is
  inside `bin/`.
- The checksum file lists every platform. Grep for the exact asset name before
  `sha256sum -c`; checking the whole file fails on assets you did not download.
- `install -m 0755` avoids a separate `chmod` and works on a read-only source
  tree.
- Install as root into `/usr/local/bin` if the command is for every user, or as
  `agent` into `/home/agent/.npm-global/bin` for npm packages.
- If the tool reads configuration on first run, create its config directory in
  the Dockerfile and chown it to `agent` so the sandbox can write to it.

## Worked example: gh

The descriptors declare:

```yaml
  - type: com.docker.sandbox/network-policy@1
    config:
      runtime:
        allow:
          - api.commandcode.ai:443
          - api.github.com:443
          - github.com:443

  - type: com.docker.sandbox/credential@1
    optional: true
    description: GitHub API access for gh
    config:
      service: github
      phase: runtime
      apiKey:
        name: GH_TOKEN
        proxyManaged: true
        inject:
          - domain: api.github.com
            header: Authorization
            format: "Bearer %s"
          - domain: github.com
            header: Authorization
            format: "Bearer %s"
```

Store the token on the host with `sbx secret set github`, approve the binding on
first create, and verify from inside the sandbox:

```bash
sbx exec cmd-demo sh -c 'gh auth status; gh api user -q .login'
```

`gh auth status` reports the real account while `GH_TOKEN` holds only
`proxy-managed`.
