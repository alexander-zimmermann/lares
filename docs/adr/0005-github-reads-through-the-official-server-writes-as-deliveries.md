# GitHub reads go through GitHub's own server; GitHub writes are deliveries of the trigger

The agent platform reads GitHub through GitHub's own tool server, a
service of its own behind the gateway
([ADR 0006](0006-every-tool-server-is-an-http-endpoint-behind-one-gateway.md)).
It reads with an installation token of an App that may only read: the
External Secrets Operator mints the token from the App's key, narrowed
to reading, and the gateway attaches it to every call. Every
GitHub write — a pull request, an issue, a comment — is a delivery of the
trigger: a run ends with one fenced block per thing it wants opened, and
the trigger opens it as a second App, the write App, whose key lives in
the trigger's pod and nowhere else. The owner's correction of a repo
skill, which every profile reads from a read-only mount, is delivered the
same way: the harness's hook reports the write the mount refused, and the
trigger makes it a pull request. No surface of the harness holds a
GitHub write tool, and every GitHub-touching use case shares the one code
path.

Two reasons carry this:

- **The check before anything is opened is deterministic.** The model is
  the scout, the cluster is the judge. Before GitHub is written to, the
  trigger checks every block's fields, every label against the repository,
  and for a pull request applies the diff to the file on the default
  branch's head. A block that does not hold opens nothing: a diff that does
  not apply is a failed run with `AgentRunFailed`, never a broken pull
  request, and a label the repository lacks is never created on the fly.
  A skill correction is applied exactly, to the file on the default branch
  or on its open pull request's branch, and one that does not apply opens
  nothing either.
- **Reading and writing are two identities.** The harness reads issues,
  pull requests and files that anyone can write into; whatever such a text
  talks the model into, the harness holds no GitHub token, and the one
  the gateway attaches only reads. The write App's
  pull requests appear as `lares-agent-writer[bot]` with the
  label `agent/proposal`, and the trigger reads their outcome back into the
  ledger, so the merged share of Propose is a count, not a guess.

## Considered options

- **A write instance of GitHub's own server, granted to the use cases
  that open pull requests**: the model would open the pull request itself,
  so the check before it would be the model's. The harness's Jobs API gives
  a cron job no tool list of its own, so the write would reach every cron
  job, steered by every text the model reads.
- **One App for reading and writing, its read tokens narrowed by the
  minter**: the External Secrets Operator narrows each token it mints,
  but the key that mints the read token would mint write tokens too, and
  GitHub would show reading and writing as one identity.
- **The model writes the change, a person opens the pull request**: keeps
  every check with a person and every proposal one manual step away from
  being reviewable, which is the cost the platform exists to remove.
