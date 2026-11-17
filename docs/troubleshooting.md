# Troubleshooting

## `failed to connect to the docker API`

The kit build uses the host Docker API. Start Docker Desktop or another engine.
Sandboxes and cached kit builds run without it; only a rebuild needs it.

## `required credential has no binding`

Approve the prompt with `1` on an interactive create, or pre-write the binding in
`~/.config/sbx/credentials.yaml` for CI. The value comes from
`sbx secret set <service>`. The kit is third party, so it always needs approval.

Example binding:

```yaml
bindings:
    commandcode:
        apiKey:
            domains:
                - api.commandcode.ai
    github:
        apiKey:
            domains:
                - api.github.com
                - github.com
```

## 403 from a host you allowed

Check for centralized governance. Under an organization policy, local and kit
allow rules can be inactive:

```bash
sbx policy check network api.commandcode.ai --sandbox command-code
sbx policy ls --include-inactive
```

Look for `inactive` and a footnote about corporate policy taking precedence.
Signing in with an account that is not governed removes the restriction.

## `x509: certificate signed by unknown authority`

The proxy CA did not reach the trust store the client reads. Check that
`/etc/ssl/certs/ca-certificates.crt` exists and that `NODE_EXTRA_CA_CERTS`
points at it. On a different base image, also check that
`/usr/local/share/ca-certificates` exists and that `update-ca-certificates` is
installed; some minimal images ship without them.

## `gh auth status` says the token is invalid

The GitHub binding is missing or the stored secret is not set. Run
`sbx secret set github` and approve the binding. Inside the sandbox, `GH_TOKEN`
should read `proxy-managed`; the proxy replaces it on the way out.

## `cmd: command not found`

The kit installs the package as root with npm's default prefix, so `cmd` lands
in `/usr/local/bin`. If you changed the base image or set `NPM_CONFIG_PREFIX`,
check that the prefix's `bin` is on `PATH` for the `agent` user.

## `npm i -g` inside the sandbox fails

Two reasons, both deliberate. The global prefix is owned by root, so the agent
cannot replace installed packages, and the policy does not allow the npm
registry at run time. Auto-update is disabled for the same reason. To change
the Command Code version, rebuild with `--kit-arg version=x.y.z`.

## The sandbox starts but every model call fails

Two common causes: the credential was not approved (see above), or egress is
denied by governance. Confirm with:

```bash
sbx exec command-code sh -c 'echo $COMMAND_CODE_API_KEY'
sbx policy log command-code
```

The variable should print `proxy-managed`, and the log should show allowed
requests to `api.commandcode.ai`.

## A rebuild did not pick up my changes

An existing sandbox keeps the image and entrypoint it was created with. Create a
sandbox with a different name, or remove and recreate it:

```bash
sbx rm --force command-code
sbx create --name command-code ./command-code ./examples/hello-cmd
```
