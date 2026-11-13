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
sbx policy check network api.commandcode.ai --sandbox cmd-demo
sbx policy ls --include-inactive
```

Look for `inactive` and a footnote about corporate policy taking precedence.
Signing in with an account that is not governed removes the restriction.

## `x509: certificate signed by unknown authority`

On DHI, the proxy CA has nowhere to land. Create
`/usr/local/share/ca-certificates` and run `update-ca-certificates` in the
Dockerfile. On other images, check that `/etc/ssl/certs/ca-certificates.crt`
exists and that `SSL_CERT_FILE` and `NODE_EXTRA_CA_CERTS` point at it.

## `gh auth status` says the token is invalid

The GitHub binding is missing or the stored secret is not set. Run
`sbx secret set github` and approve the binding. Inside the sandbox, `GH_TOKEN`
should read `proxy-managed`; the proxy replaces it on the way out.

## `cmd: command not found`

The npm global prefix is `/home/agent/.npm-global` and `PATH` includes its `bin`.
The kit also links `cmd` into `/usr/local/bin`. If you built a different image,
check both paths and that the install ran as `agent`.

## `npm i -g` inside the sandbox fails

The sandbox policy does not allow the npm registry. Add it to your own policy or
to a mixin; the kit deliberately does not allow it at run time. Auto-update is
disabled for the same reason.

## The sandbox starts but every model call fails

Two common causes: the credential was not approved (see above), or egress is
denied by governance. Confirm with:

```bash
sbx exec cmd-demo sh -c 'echo $COMMAND_CODE_API_KEY'
sbx policy log cmd-demo
```

The variable should print `proxy-managed`, and the log should show allowed
requests to `api.commandcode.ai`.

## A rebuild did not pick up my changes

An existing sandbox keeps the image and entrypoint it was created with. Create a
sandbox with a different name, or remove and recreate it:

```bash
sbx rm --force cmd-demo
sbx create --name cmd-demo ./command-code ./examples/hello-cmd
```
