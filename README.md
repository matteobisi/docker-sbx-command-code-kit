# Docker Sandboxes kit for Command Code (cmd)

A [Docker Sandboxes](https://docs.docker.com/ai/sandboxes) v3 workload kit for
[Command Code](https://commandcode.ai), the coding agent whose TUI is `cmd`.
It also installs the GitHub CLI as a worked example of adding another command.

`sbx` ships no Command Code template. This kit runs `cmd` inside a microVM with
a proxy-managed API key, a short egress allow list and no access to the host.

Companion article with the full walkthrough and measurements:
**https://www.msbiro.net/posts/docker-sbx-command-code-kit/**

The kit lives in `command-code/`: a descriptor and a Dockerfile on
`node:22-bookworm-slim`.

## Requirements

- `sbx` v0.45 or later, for the v3 kit schema
- A Docker engine for local kit builds. Cached builds do not need it.
- A Command Code API key, from https://commandcode.ai/studio or your plan
- Optional: a GitHub token for `gh`

## Quick start

```bash
git clone https://github.com/matteobisi/docker-sbx-command-code-kit.git
cd docker-sbx-command-code-kit

sbx login
sbx secret set commandcode
sbx secret set github        # optional, for gh

sbx create --name command-code ./command-code ./examples/hello-cmd
sbx run --name command-code
```

The first create asks you to approve the kit's credential requests. Choose
`1. Approve all`; the default is `3. No`, which starts the sandbox without
credentials. Replace `./examples/hello-cmd` with your own project when ready.

## Documentation

- [Architecture, credentials and security](docs/architecture.md)
- [Usage, arguments and updating](docs/usage.md)
- [Adding more commands](docs/adding-commands.md)
- [Troubleshooting](docs/troubleshooting.md)

## License

The kit files and documentation are licensed under Apache-2.0. See
[LICENSE](LICENSE). Command Code ships as an `UNLICENSED` npm package; this
repository does not redistribute it, it installs the package at image build time.
