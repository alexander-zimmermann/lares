# Every tool server is an HTTP endpoint behind one gateway; models stay with the harness

Every tool server a use case names is an HTTP endpoint behind a route of
its own on one gateway, agentgateway, in the agents' namespace. The
harness calls a route with a key that is valid on that route only. The
gateway serves the server's declared tool list and nothing else, and
attaches the credential the server expects, taken from a Kubernetes
Secret beside it. The harness holds no tool server's credential, so a
server's route is its only way to the server, and no tool server runs as
a process of the harness or of the gateway. Models are not behind the
gateway: the harness calls them itself.

Four reasons carry this:

- **One kind of server, one way to run it.** A server the harness starts
  as a child process runs once per profile, holds its credential in the
  harness's pod, and restarts the harness with every one of its image
  bumps. A server behind the gateway is a Deployment of its own: a bump
  rolls that pod only, and its credential reaches the gateway alone.
- **The ceiling sits outside the model's context.** The route's tool
  list, rendered from the use-case file, decides what a caller may list
  and call; the harness's own include list stays on top of it. A key
  opens its one route, so a use case holds exactly the servers it is
  granted.
- **A renewed credential needs no restart.** The gateway watches its
  routes file and every credential file, kubelet swaps a changed Secret
  in whole, and a route keeps no session with its server, so the next
  call carries the new value. GitHub's installation token is renewed
  every 30 minutes this way.
- **One place sees every tool call.** The gateway sends a span of every
  call to the trace collector and counts the calls for Prometheus, for
  servers that trace nothing themselves too.

Models stay with the harness because its subscription login is the
harness's own, one per profile, and cannot be handed to another
process; the harness's hook already reports every model call with its
cost.

## Considered options

- **Each server authenticating its callers, called by the harness
  directly**: the harness would hold one credential per server and each
  server would enforce its own tool list. GitHub's own server
  authenticates nobody; it acts for whoever brings a token.
- **Several servers behind one route**: one failing server fails the
  handshake of every server behind it, and use cases are granted per
  tool server, not per route.
- **Child-process servers inside the gateway**: keeps one door, but the
  gateway restarts with every server's bump and holds each server's
  credential in its own environment. GitHub's server speaks HTTP; only
  its App sign-in needs a child process, and the token can be minted
  outside it.
- **Models behind the gateway too**: the subscription login can only be
  passed through, and the costs are already counted where the calls are
  made.
