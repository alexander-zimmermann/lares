# GitHub reads go through GitHub's own server; GitHub writes are deliveries of the trigger

The agent platform reads GitHub through GitHub's own tool server, which
the harness starts signed in as an App that may only read. Every
GitHub write — a pull request, an issue, a comment — is a delivery of the
trigger: a run ends with one fenced block per thing it wants opened, and
the trigger opens it as a second App, the write App, whose key lives in
the trigger's pod and nowhere else. No surface of the harness holds a
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
- **Reading and writing are two identities.** The harness reads issues,
  pull requests and files that anyone can write into; whatever such a text
  talks the model into, it holds no token that writes. The write App's
  pull requests appear as `homelab-zimmermann-lares-agent[bot]` with the
  label `agent/proposal`, and the trigger reads their outcome back into the
  ledger, so the merged share of Propose is a count, not a guess.

## Considered options

- **A write instance of GitHub's own server, granted to the use cases
  that open pull requests**: the model would open the pull request itself,
  so the check before it would be the model's. The harness's Jobs API gives
  a cron job no tool list of its own, so the write would reach every cron
  job, and the write key would sit in the harness's pod beside every text
  the model reads.
- **One App for reading and writing, its tokens narrowed to reading for
  the harness**: the narrowing needs a minter beside the harness that holds
  the full key in the harness's pod, and GitHub's own server, signing in
  as the App itself, would mint unnarrowed tokens from the same key.
- **The model writes the change, a person opens the pull request**: keeps
  every check with a person and every proposal one manual step away from
  being reviewable, which is the cost the platform exists to remove.
