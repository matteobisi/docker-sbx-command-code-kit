# Architecture, credentials and security

The kit is a `workload`, so it supplies the base environment and the launch
command. Its capabilities tell `sbx` what to arrange around the image.

| Capability | What it does here |
|---|---|
| `sbx@1` | The host launches `cmd` instead of running the image entrypoint as PID 1 |
| `network-policy@1` | Allows only `api.commandcode.ai`, `api.github.com`, `github.com` over 443 |
| `credential@1` (commandcode) | Injects the Command Code key into `api.commandcode.ai` as `Authorization: Bearer` |
| `credential@1` (github) | Injects the GitHub token into GitHub as `Authorization: Bearer`, for `gh` |
| `agent-context@1` | Writes `/home/agent/.commandcode/AGENTS.md` with the sandbox rules |

The descriptor declares those requests; the Dockerfile installs the software.
`sbx` validates the pair at build time, so a misspelled capability key fails the
build instead of silently dropping a policy.

## Credential flow

Inside the sandbox, `COMMAND_CODE_API_KEY` and `GH_TOKEN` are set to
`proxy-managed`. The host proxy replaces the header on the way out, so the real
credentials never enter the VM. Model traffic and GitHub traffic use the same
mechanism with different services.

Values live on the host in the keychain. `sbx secret set commandcode` and
`sbx secret set github` store them; `~/.config/sbx/credentials.yaml` records only
which services and domains you approved. The kit is third party, so `sbx` asks
for that approval on first create.

`commandcode` is a service name the kit declares. `github` is a built-in service,
so its domain list and `GH_TOKEN` name already exist. That is the pattern for any
provider `sbx` knows.

## Image layout

The platform floor is a non-root `agent` user with uid 1000, bash, git, a CA
store, and a writable home. The Node image already uses uid 1000 for a user
called `node`, so the Dockerfile replaces that account rather than creating a
second one.

`cmd` is installed with `npm i -g command-code@latest`. The package exposes four
binaries that point at the same entry point: `cmd`, `cmdc`, `command-code`, and
`commandcode`. The kit links `cmd` into `/usr/local/bin`, so it resolves even if
`PATH` changes, and the build asserts that both paths resolve to the same file.

The npm install clears its cache in the same layer. Without that step the image
carries about 400 MB of tarballs that no run needs.

`gh` is installed from the official release tarball with the checksum verified
and `TARGETARCH` selecting the architecture, so the same recipe builds for arm64
and amd64. BuildKit only exposes `TARGETARCH` when the Dockerfile declares it
with `ARG TARGETARCH`.

The certificate variables (`SSL_CERT_FILE`, `NODE_EXTRA_CA_CERTS`) point at the
system bundle because every HTTPS request leaves through a proxy that terminates
TLS with its own CA.

## Launch behaviour

The entrypoint is:

```text
cmd --yolo --trust --skip-onboarding --no-auto-update
```

`--yolo` disables permission prompts, `--trust` skips the project trust question,
`--skip-onboarding` avoids the first-run taste prompt, and `--no-auto-update`
keeps the installed version in place. `sbx exec` runs a binary directly and
ignores the entrypoint, so these flags apply only through `sbx run`.

## Security notes

The microVM is the boundary. The workspace is bind-mounted read-write and changes
appear on the host immediately; everything outside it is out of reach, including
SSH keys and the host Docker socket. Egress is limited to the hosts above, and a
deny always wins over an allow.

The entrypoint runs `cmd` in YOLO mode because the sandbox is what makes that
safe. Review the agent's output before it goes anywhere: `git diff` for the code,
and check Git hooks, Makefiles and CI configuration too, because they do not show
up in a diff once committed.

Credentials stay on the host. `sbx secret ls` shows what is stored, and the real
values never enter the VM.

## Repository layout

```text
.
├── command-code/
│   ├── command-code.yaml
│   └── command-code.dockerfile
├── command-code-dhi/
│   ├── command-code-dhi.yaml
│   └── command-code-dhi.dockerfile
├── docs/
├── examples/
│   └── hello-cmd/
│       ├── README.md
│       └── greet.js
├── LICENSE
└── README.md
```
