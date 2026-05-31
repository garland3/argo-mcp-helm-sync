# argo-mcp-helm-sync

One reusable Helm chart for **all** your MCP servers, with **Argo CD** (OpenShift
GitOps) generating a **prod** and a **qual** instance of each server, and
secrets pulled from **HashiCorp Vault** via the **Argo CD Vault Plugin (AVP)**.

```
┌─────────────────────┐     ApplicationSet (matrix generator)
│ servers/*.yaml      │ ──▶ servers/*.yaml  ×  [prod, qual]
│ (one file/server)   │           │
└─────────────────────┘           ▼
┌─────────────────────┐     N Argo CD Applications
│ chart/  (shared)    │ ──▶ mcp-example-server-prod
│ the single chart    │     mcp-example-server-qual
└─────────────────────┘     mcp-weather-server-prod ...
                                  │  helm template + AVP
                                  ▼
                            rendered manifests on OpenShift
                            (secrets resolved from Vault)
```

## Layout

| Path | What it is |
|------|------------|
| `chart/` | The **single** reusable Helm chart every MCP server uses. |
| `servers/<name>.yaml` | One file per MCP server (registry, image, env vars, secret refs). **Drop a file here = a new server gets prod+qual automatically.** |
| `argocd/applicationset.yaml` | Matrix generator: `servers/*.yaml` × `[prod, qual]`. |
| `argocd/appproject.yaml` | AppProject scoping the generated Applications. |
| `argocd/cmp-plugin.yaml` | The AVP+Helm Config Management Plugin (resolves Vault refs at sync). |

## How prod/qual fan-out works

The ApplicationSet uses a **matrix** of two generators:

1. **git files** — one parameter set per `servers/*.yaml`.
2. **list** — `[prod, qual]`, each carrying its own `vaultMount`, `replicas`,
   `destNamespace`, and `autoSync`.

Their cross-product yields one Application per `(server, env)`. Each Application
renders the shared `chart/` with:

```
--values ../servers/<name>.yaml      # the server's own config
--set env.name=<prod|qual>           # injected by the generator
--set env.vaultMount=secret/data/mcp/<env>
--set replicaCount=<env replicas>
```

## How secret auto-routing works

In a server file you reference Vault using the literal token `{{vault}}` as the
per-environment prefix:

```yaml
secretEnv:
  OPENAI_API_KEY: "<path:{{vault}}/example-server#openai_api_key>"
```

The chart substitutes `{{vault}}` with the env's `vaultMount`, so the **same
line** renders as:

| env  | rendered reference |
|------|--------------------|
| prod | `<path:secret/data/mcp/prod/example-server#openai_api_key>` |
| qual | `<path:secret/data/mcp/qual/example-server#openai_api_key>` |

Helm leaves the `<path:...>` token untouched. At sync time the **Argo CD Vault
Plugin** reads it from Vault and writes the real value into a Kubernetes
`Secret`. Nothing sensitive ever lives in git.

## Add a new MCP server

1. Copy `servers/example-server.yaml` to `servers/my-server.yaml`.
2. Set `nameOverride`, `image.*`, `extraEnv`, and `secretEnv`.
3. Put the matching secrets in Vault under
   `secret/mcp/prod/my-server` and `secret/mcp/qual/my-server`.
4. Commit. Argo creates `mcp-my-server-prod` and `mcp-my-server-qual`.

## Per-server knobs

See `chart/values.yaml` for every option (image/registry, `extraEnv`,
`secretEnv`, `service`, OpenShift `route`, probes, resources, SCC-friendly
security context, etc.).

## Environment differences

Set in the `list` generator in `argocd/applicationset.yaml`:

| | prod | qual |
|---|---|---|
| namespace | `mcp-prod` | `mcp-qual` |
| Vault mount | `secret/data/mcp/prod` | `secret/data/mcp/qual` |
| replicas | 2 | 1 |
| sync | manual / gated | auto (self-heal + prune) |

## Render locally (what AVP runs, minus Vault)

```bash
helm template example-server ./chart \
  --values ./servers/example-server.yaml \
  --set env.name=qual \
  --set env.vaultMount=secret/data/mcp/qual \
  --set replicaCount=1
```

The output will contain `<path:...>` tokens; those are resolved by AVP in the
cluster, not by `helm template`.

## Install on OpenShift GitOps

```bash
oc apply -f argocd/cmp-plugin.yaml      # register the AVP+Helm sidecar config
# add the sidecar to your ArgoCD CR (see comments in cmp-plugin.yaml)
oc apply -f argocd/appproject.yaml
oc apply -f argocd/applicationset.yaml
```

AVP authenticates to Vault with the Kubernetes auth method, using role
`argocd-<env>` (set per env in the ApplicationSet). Configure those roles and
policies in Vault to scope each env to its own `secret/mcp/<env>/*` path.
