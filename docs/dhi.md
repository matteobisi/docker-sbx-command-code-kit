# The DHI variant

`command-code-dhi/` is the same kit on a Docker Hardened Image base. I measured
both rather than assuming, building for arm64 with the same Command Code release
and the same `gh` version:

| Base | Base size | Final as built | After `npm cache clean` |
|---|---|---|---|
| `node:22-bookworm-slim` | 349 MB | 1.39 GB | 878 MB |
| `dhi.io/node:22-debian12-dev` | 502 MB | 1.19 GB | 902 MB |

The "as built" column is misleading. The standard image carries npm 10, which
leaves a 409 MB cache in `/home/agent/.npm/_cacache`; DHI carries npm 11 and
leaves 219 MB. Clear the cache and the standard image is 24 MB smaller, because
the DHI dev base is 153 MB larger to start with.

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

## DHI-specific fixes

Two details will cost you a build each:

- `dhi.io/node:22-debian12-dev` lacks `gzip`, which the `gh` tarball needs. Add it
  to the apt install list.
- It lacks `/usr/local/share/ca-certificates`, where `sbx` puts its proxy CA.
  Without that directory the injection fails silently and every TLS call fails
  with `x509: certificate signed by unknown authority`. The Dockerfile creates
  the directory and runs `update-ca-certificates`.

The DHI Dockerfile also declares `ARG TARGETARCH`, because the `gh` install needs
it and BuildKit does not expose it implicitly.
