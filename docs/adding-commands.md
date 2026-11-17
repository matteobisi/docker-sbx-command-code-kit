# Adding more commands

The `gh` install in the Dockerfile is the template to copy:

```dockerfile
ARG TARGETARCH
RUN asset="gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" \
 && base="https://github.com/cli/cli/releases/download/v${GH_VERSION}" \
 && curl -fsSLo /tmp/gh.tgz "${base}/${asset}" \
 && echo "$(curl -fsSL "${base}/gh_${GH_VERSION}_checksums.txt" | grep " ${asset}\$" | cut -d' ' -f1)  /tmp/gh.tgz" \
      | sha256sum -c - \
 && tar -xzf /tmp/gh.tgz -C /usr/local --strip-components=1 --wildcards '*/bin/gh' \
 && rm /tmp/gh.tgz
```

BuildKit only exposes `TARGETARCH` when the Dockerfile declares it with
`ARG TARGETARCH`. Without the declaration the variable is empty and the download
fails. `gh` names its assets `amd64` and `arm64`, like `TARGETARCH`; a tool with
different names (`x86_64`, `aarch64`) needs a mapping.

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
  inside `bin/`. `--strip-components=1` with a `*/bin/gh` filter extracts only
  the binary into `/usr/local/bin`.
- The checksum file lists every platform. Pick the line for the exact asset;
  checking the whole file fails on assets you did not download.
- Install as root, into `/usr/local`. The binary is then on `PATH` and the agent
  cannot modify it. The same applies to npm packages: `npm i -g` as root.
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
sbx exec command-code sh -c 'gh auth status; gh api user -q .login'
```

`gh auth status` reports the real account while `GH_TOKEN` holds only
`proxy-managed`.
