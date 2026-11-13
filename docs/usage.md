# Usage, arguments and updating

## Create and launch

Create a sandbox and attach to it:

```bash
sbx run ./command-code ~/projects/hello-cmd
```

Create without attaching, then launch by name:

```bash
sbx create --name cmd-demo ./command-code ~/projects/hello-cmd
sbx run --name cmd-demo
```

`sbx run` with a kit path creates a new sandbox. `sbx run --name NAME` attaches to
an existing one and uses the entrypoint it was created with.

## Permission modes

The entrypoint runs `cmd` in YOLO mode. To get the normal permission ladder
instead:

```bash
sbx exec -it cmd-demo cmd --permission-mode default
```

Headless, non-interactive:

```bash
sbx exec cmd-demo cmd -p "summarise this repository"
```

`sbx exec` runs the binary directly and ignores the image entrypoint, so no
default flags apply.

## Kit arguments

| Argument | Default | Purpose |
|---|---|---|
| `version` | `latest` | Command Code release, or an `x.y.z` pin |
| `ghVersion` | `2.103.3` | GitHub CLI release |

Pin both:

```bash
sbx create --name cmd-pinned \
  --kit-arg version=1.88.5 \
  --kit-arg ghVersion=2.103.3 \
  ./command-code ~/projects/hello-cmd
```

`latest` resolves once at build time and the build is cached while the source and
arguments are unchanged. Pass an explicit version when you need reproducibility.

## Updating a sandbox

Edit the descriptor or Dockerfile, then create a sandbox with a different name to
force a rebuild. An existing sandbox keeps the image and entrypoint it was created
with. To move it to a new build, remove and recreate it:

```bash
sbx rm --force cmd-demo
sbx create --name cmd-demo ./command-code ~/projects/hello-cmd
```

## Publishing the kit

Both kits are also valid build files for Buildx. To publish the standard one:

```bash
docker login
docker buildx build ./command-code \
  --file ./command-code/command-code.yaml \
  --platform linux/arm64,linux/amd64 \
  --tag docker.io/<NAMESPACE>/command-code:1.0.0 \
  --push
```

Then run it by reference:

```bash
sbx run --name cmd-mine docker.io/<NAMESPACE>/command-code:1.0.0 ~/projects/hello-cmd
```

Command Code ships as an `UNLICENSED` npm package. Check the upstream terms
before publishing an image that contains it.
