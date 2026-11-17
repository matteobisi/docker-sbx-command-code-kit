# Usage, arguments and updating

## Validate

```bash
sbx kit validate ./command-code
sbx kit inspect ./command-code
```

Both commands are experimental in `sbx`. `inspect` prints the resolved network
rules, credentials and launch command.

## Create and launch

Create a sandbox and attach to it:

```bash
sbx run ./command-code ~/projects/hello-cmd
```

Create without attaching, then launch by name:

```bash
sbx create --name command-code ./command-code ~/projects/hello-cmd
sbx run --name command-code
```

`sbx run` with a kit path creates a new sandbox. `sbx run --name NAME` attaches to
an existing one and uses the entrypoint it was created with.

## Permission modes

The entrypoint runs `cmd` in YOLO mode. To get the normal permission ladder
instead:

```bash
sbx exec -it command-code cmd --permission-mode default
```

Headless, non-interactive:

```bash
sbx exec command-code cmd -p "summarise this repository"
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
sbx create --name command-code-pinned \
  --kit-arg version=1.88.5 \
  --kit-arg ghVersion=2.103.3 \
  ./command-code ~/projects/hello-cmd
```

`latest` resolves once at build time and the build is cached while the source and
arguments are unchanged. Pass an explicit version when you need reproducibility.

## Updating Command Code

A new Command Code release needs no Dockerfile change. Rebuild the same kit with
the new version as an argument. An existing sandbox keeps the image it was
created with, so remove it and create it again:

```bash
npm view command-code version
sbx rm --force command-code
sbx create --name command-code --kit-arg version=1.89.3 \
  ./command-code ~/projects/hello-cmd
```

The new argument value invalidates the build cache from the npm layer onwards.
The apt and `gh` layers are reused. The workspace is on the host and is not
affected; anything stored only inside the sandbox, such as Command Code's session
history in `~/.commandcode`, is removed with it.

Rebuilding with `latest` gives you the cached release. To force a fresh
resolution, clear the kit build cache with `sbx kit builder rm` (experimental;
this removes the cache for every kit).

## Updating the kit

After editing the descriptor or the Dockerfile, remove and recreate the sandbox
the same way. The changed files invalidate the cache, so no argument is needed.

## Publishing the kit

The descriptor is also a valid build file for Buildx. To publish it:

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
sbx run --name command-code-hub docker.io/<NAMESPACE>/command-code:1.0.0 ~/projects/hello-cmd
```

Command Code ships as an `UNLICENSED` npm package. Check the upstream terms
before publishing an image that contains it.
