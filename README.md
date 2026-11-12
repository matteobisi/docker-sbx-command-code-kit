# Docker Sandboxes kits for Command Code (cmd)

Two [Docker Sandboxes](https://docs.docker.com/ai/sandboxes) v3 workload kits for
[Command Code](https://commandcode.ai), the coding agent whose TUI is `cmd`.
Both kits also install the GitHub CLI as a worked example of adding another
command to an agent image.

`sbx` does not ship a Command Code template. These kits fill that gap: the agent
runs inside a microVM with a proxy-managed API key, a short egress allow list and
no access to the host.

Companion article with the full walkthrough and measurements:
**https://www.msbiro.net/posts/docker-sbx-command-code-kit/**

## What you get

| Directory | Base image | Notes |
|---|---|---|
| `command-code/` | `node:22-bookworm-slim` | Recommended. `cmd` plus `gh`. |
| `command-code-dhi/` | `dhi.io/node:22-debian12-dev` | Same tools on a Docker Hardened Image base. |

Each directory contains a kit descriptor (`*.yaml`) and its Dockerfile
(`*.dockerfile`). The descriptor declares the network rules, the credentials and
the base environment; the Dockerfile installs the software.

## Requirements

- `sbx` v0.45 or later, because the kits use the v3 schema
- A Docker engine while you build a local kit. `sbx` runs sandboxes without
  Docker Desktop, but a local kit build uses the host Docker API. A cached build
  does not need it.
- A Command Code API key. Create one at https://commandcode.ai/studio or use the
  key from your plan.
- Optional: a GitHub token, if you want `gh` authenticated inside the sandbox.

## Quick start

```bash
git clone https://github.com/matteobisi/docker-sbx-command-code-kit.git
cd docker-sbx-command-code-kit

# 1. Sign in to Docker Sandboxes
sbx login

# 2. Store the Command Code key on the host (not in the image, not in the repo)
sbx secret set commandcode

# 3. Optional, for gh
sbx secret set github

# 4. Create a sandbox from the kit and mount a project
sbx create --name cmd-demo ./command-code ~/projects/hello-cmd

# 5. Launch the TUI
sbx run --name cmd-demo
```

The first create asks you to approve the kit's credential requests because the
kit is third party:

```text
This kit wants to use these credentials:
  commandcode:  API key sent to api.commandcode.ai (stored)
  github:       API key sent to api.github.com, github.com (stored)

Approve these credentials?
  1. Approve all
  2. Review each
  3. No   start without them
Choice [1-3, default 3]:
```

Choose `1`. The default is `3`, so pressing Enter approves nothing and the first
API call fails with an authentication error that looks like a network problem.
The approval is written to `~/.config/sbx/credentials.yaml`. The key values stay
in the keychain; that file records the domains you approved.

There is no example project in the sandbox unless you pass one. This repository
includes `examples/hello-cmd` if you want something disposable to start with.

## Using the kits

Create and launch in one step:

```bash
sbx run ./command-code ~/projects/hello-cmd
```

`sbx run` uses the kit's entrypoint, which is `cmd` in YOLO mode with project
trust and auto-update disabled. To get the normal permission ladder instead:

```bash
sbx exec -it cmd-demo cmd --permission-mode default
```

Headless, non-interactive:

```bash
sbx exec cmd-demo cmd -p "summarise this repository"
```

Pin a release instead of installing `latest`:

```bash
sbx create --name cmd-pinned --kit-arg version=1.88.5 ./command-code ~/projects/hello-cmd
```

Kit arguments:

| Argument | Default | Purpose |
|---|---|---|
| `version` | `latest` | Command Code release, or an `x.y.z` pin |
| `ghVersion` | `2.103.3` | GitHub CLI release |

## How it works

The kit is a `workload`, so it supplies the base environment and the launch
command. Its capabilities tell `sbx` what to arrange around the image:

| Capability | What it does here |
|---|---|
| `sbx@1` | The host launches `cmd` instead of running the image entrypoint as PID 1 |
| `network-policy@1` | Allows only `api.commandcode.ai`, `api.github.com`, `github.com` over 443 |
| `credential@1` (commandcode) | Injects the Command Code key into `api.commandcode.ai` as `Authorization: Bearer` |
| `credential@1` (github) | Injects the GitHub token into GitHub as `Authorization: Bearer`, for `gh` |
| `agent-context@1` | Writes `/home/agent/.commandcode/AGENTS.md` with the sandbox rules |

Inside the sandbox, `COMMAND_CODE_API_KEY` and `GH_TOKEN` are set to
`proxy-managed`. The host proxy replaces the header on the way out, so the real
credentials never enter the VM. Model traffic and GitHub traffic go through the
same mechanism with different services.

The image follows the sandbox platform floor: a non-root `agent` user with uid
1000, bash, git, a CA store, and a writable home. The Node image already uses uid
1000 for a user called `node`, so the Dockerfile replaces that account rather
than creating a second one.

The npm install clears its cache in the same layer. Without that step the image
carries about 400 MB of tarballs that no run needs.

`gh` is installed from the official release tarball with the checksum verified
and `TARGETARCH` selecting the architecture, so the same recipe builds for arm64
and amd64. BuildKit only exposes `TARGETARCH` when the Dockerfile declares it
with `ARG TARGETARCH`.

## Adding more commands

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

Adding a command has three parts:

1. **Install it in the image.** Prefer a pinned release with a checksum over a
   package manager that resolves `latest` at build time. Declare every build
   argument.
2. **Allow its network destinations** in `network-policy@1`. A credential's
   inject domains must also appear in that allow list, or the kit fails
   validation.
3. **Declare its credential** if it needs one. Use a built-in service name when
   one exists (`github`, `anthropic`, `openai`, and others), or make up a service
   name and store it with `sbx secret set <name>`. Approve the binding on first
   create.

Keep tool-specific access rules in the kit, so they travel with the tool when it
is combined with another workload.

## The DHI variant

`command-code-dhi/` is the same kit on a Docker Hardened Image base. I measured
both rather than assuming, building for arm64 with the same Command Code release:

| Base | Base size | Final as built | After `npm cache clean` |
|---|---|---|---|
| `node:22-bookworm-slim` | 349 MB | 1.39 GB | 878 MB |
| `dhi.io/node:22-debian12-dev` | 502 MB | 1.19 GB | 902 MB |

The "as built" column is misleading. The standard image carries npm 10, which
leaves a 409 MB cache; DHI carries npm 11 and leaves 219 MB. Clear the cache and
the standard image is 24 MB smaller, because the DHI dev base is 153 MB larger
to start with.

Docker Scout totals on the final images (they drift over time):

```text
node:22-bookworm-slim         130 total   0C  28H  23M  67L  12?
dhi.io/node:22-debian12-dev   123 total   0C  24H  22M  65L  12?
```

Seven findings apart. Both images carry the same application layer: 191 npm
package directories, 267 MB, plus the same `gh` binary. The difference is in the
base packages. The Debian packages I checked (libc6, libssl3, openssl, zlib1g,
libgnutls30, git, curl) are the same versions, because both bases are Debian 12
at the current patch level.

The DHI runtime variant is 184 MB but has no shell and no apt, so it cannot
satisfy the sandbox platform floor. The `-dev` variant keeps bash, apt and git,
which is most of the surface the hardening was meant to remove.

Use DHI when you can run the runtime variant, or when signed images, SBOM and
provenance matter more than size. For this kit the standard image is the better
default.

If you build on DHI, two details will cost you a build each:

- `dhi.io/node:22-debian12-dev` lacks `gzip`, which the `gh` tarball needs.
- It lacks `/usr/local/share/ca-certificates`, where `sbx` puts its proxy CA.
  Without that directory the injection fails silently and every TLS call fails
  with `x509: certificate signed by unknown authority`. The Dockerfile creates
  the directory and runs `update-ca-certificates`.

## Security notes

The microVM is the boundary. The workspace is bind-mounted read-write and changes
appear on the host immediately; everything outside it is out of reach, including
SSH keys and the host Docker socket. Egress is limited to the hosts above and a
deny always wins over an allow.

The entrypoint runs `cmd` with `--yolo`, because the sandbox is what makes that
safe. Review the agent's output before it goes anywhere: `git diff` for the code,
and check Git hooks, Makefiles and CI configuration too, because they do not show
up in a diff once committed.

Credentials stay on the host. `COMMAND_CODE_API_KEY` and `GH_TOKEN` are
placeholders inside the VM, and `sbx secret ls` shows what is stored. The real
values are in the macOS keychain.

## Troubleshooting

**`failed to connect to the docker API`** when building a kit: start Docker
Desktop or another engine. Cached kit builds do not need it.

**`required credential has no binding`**: approve the prompt with `1` on an
interactive create, or pre-write the binding in `~/.config/sbx/credentials.yaml`
for CI. The value comes from `sbx secret set <service>`.

**403 from a host you allowed**: check for centralized governance. Under an
organization policy, local and kit allow rules can be inactive:

```bash
sbx policy check network api.commandcode.ai --sandbox cmd-demo
sbx policy ls --include-inactive
```

**`x509: certificate signed by unknown authority`** on DHI: the proxy CA has
nowhere to land. Create `/usr/local/share/ca-certificates` and run
`update-ca-certificates` in the Dockerfile.

**`gh auth status` says the token is invalid**: the GitHub binding is missing or
the stored secret is not set. Run `sbx secret set github` and approve the binding.

**`cmd: command not found`**: the npm global prefix is `/home/agent/.npm-global`
and `PATH` includes its `bin`. The kit also links `cmd` into `/usr/local/bin`.

**`npm i -g` inside the sandbox fails**: the sandbox policy does not allow the
npm registry. Add it to your own policy or to a mixin; the kit deliberately does
not allow it at run time.

## Updating the kits

Edit the descriptor or Dockerfile, then create a sandbox with a different name to
force a rebuild. An existing sandbox keeps the image and entrypoint it was
created with. To move a sandbox to a new build, remove and recreate it:

```bash
sbx rm --force cmd-demo
sbx create --name cmd-demo ./command-code ~/projects/hello-cmd
```

The `latest` argument resolves once and the build is cached while the source and
arguments are unchanged. Pin `version` when you need reproducibility.

## Repository layout

```text
.
├── command-code/
│   ├── command-code.yaml
│   └── command-code.dockerfile
├── command-code-dhi/
│   ├── command-code-dhi.yaml
│   └── command-code-dhi.dockerfile
├── examples/
│   └── hello-cmd/
│       ├── README.md
│       └── greet.js
├── LICENSE
└── README.md
```

## Read more

- Companion article: https://www.msbiro.net/posts/docker-sbx-command-code-kit/
- Docker Sandboxes: https://docs.docker.com/ai/sandboxes
- Kits: https://docs.docker.com/ai/sandboxes/customize/
- Kit specification v3: https://github.com/docker/sandbox-kit-spec/blob/main/docs/spec/SPEC-v3.md
- Command Code: https://commandcode.ai/docs

## License

The kit descriptors, Dockerfiles and documentation in this repository are
licensed under the Apache License 2.0. See [LICENSE](LICENSE).

Command Code is distributed as an `UNLICENSED` npm package. This repository does
not redistribute it; it installs the package at image build time. Check the
upstream terms before publishing an image that contains it.
