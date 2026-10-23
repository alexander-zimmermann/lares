# One namespace per application; a part that only serves its sibling shares it

Every application deploys into a namespace of its own, named like the
application, which its own Argo application creates. A part that exists
only for another application, has no life without it and reads its
Secrets directly shares that application's namespace instead: the
operator's plugin, the MCP server in front of one application, and the
agent platform's parts around one harness. Today these are:

| Namespace | What shares it |
| --- | --- |
| `nats` | nats, nats-operator |
| `grafana` | grafana, grafana-mcp |
| `cloudnative-pg` | cloudnative-pg, barman-cloud-plugin |
| `agents` | hermes, lares-agent-trigger, agentgateway, github-mcp-server |

A shared namespace is owned by one application, which creates it; the
others render no Namespace of their own.

A Secret is sealed once, in the namespace of the application that owns
it. Another namespace that needs it gets a clone through the Kyverno
policy `sync-cluster-secrets`, never a second SealedSecret with the same
value. Inside a shared namespace a part reads its sibling's Secret
directly: the gateway sets each profile's gateway key from
`hermes-credentials`, the Secret the harness composes its `.env` files
from, because the harness reads a profile's keys from that file alone.

Three reasons carry this:

- **A namespace is an application's boundary.** Its Secrets, its
  ServiceAccount, its Kyverno clones and its Argo application line up with
  one name, so what an application holds is read off its namespace.
- **A part without a life of its own earns no boundary.** Splitting it off
  would turn every Secret it reads into a clone, or into a value sealed
  twice, for a seam nothing else crosses.
- **The network cage does not depend on it.** The agent cage selects pods
  by the label `role: agent` (ADR 0004); which namespace a caged pod sits
  in changes nothing about where it may go.
