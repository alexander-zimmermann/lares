# Research: approval channel facts for the KNX write gate

Origin: [lares#1963](https://github.com/alexander-zimmermann/lares/issues/1963) (map: [Gate-protected KNX writes](https://github.com/alexander-zimmermann/lares/issues/1962))

Question: which facts do the three approval-channel decisions of the gate — *approval channel*,
*notification path*, *identity capture* — need, verified against primary sources?

Every statement below is taken from the vendor's own documentation or source code, linked
inline, or from files in this repository (paths given). **Nothing was checked against the
running cluster.** Facts that could not be verified from a primary source are collected in
the last section and marked as such in the text.

Versions this note is pinned to: authentik `2026.8.2` (chart and app version,
`kubernetes/applications/authentik/base/kustomization.yaml`; docs pages carry "Version: 2026.8"),
Traefik chart `41.5.0`, Hermes image `v2026.9.14`, Alertmanager docs and code on `main`
as of 2026-09-15, Discord and Pushover API docs as published on 2026-09-15.

---

## TL;DR

- **Pushover** emergency priority is a complete request/answer loop on its own: `priority=2`
  with `retry` ≥ 30 s and `expire` ≤ 10 800 s (at most 50 retries), a `receipt` in the
  response, a `callback` URL Pushover POSTs to on acknowledgement, and a receipts endpoint to
  poll or to confirm a callback. The callback carries **no signature and no secret**; the
  only documented verification is re-reading the receipt with the app token. `acknowledged_by`
  is the Pushover **user key**, `acknowledged_by_device` the device name — an account, not a
  person's identity. A normal-priority message can carry a supplementary `url` (≤ 512 chars)
  with `url_title` (≤ 100) that the app shows under the expanded notification; there is no
  priority restriction on it.
- **Discord** supports the loop with a second application: a bot token alone can `POST
  /channels/{id}/messages` with button components (needs `SEND_MESSAGES`), and clicks arrive at
  the application's **Interactions Endpoint URL** as HTTP POSTs signed with Ed25519
  (`X-Signature-Ed25519`, `X-Signature-Timestamp`, verify with the app's public key, answer
  `401` otherwise). The interaction carries the clicking user's snowflake `id` inside
  `member.user`. The initial response is due within **3 s** (deferred types 5/6/7), the token
  stays valid **15 min**. Gateway and HTTP delivery are **mutually exclusive per application**,
  and Hermes registers native slash commands over its gateway session — so the endpoint
  cannot live on `lares-agent` without taking Hermes's slash commands away.
- **Authentik** forward-auth already produces identity headers; the repo's Traefik middleware
  simply does not copy them. The `authentik` middleware in
  `kubernetes/components/ingress-controller/base/middlewares.yaml` has no
  `authResponseHeaders`; authentik's own Traefik template lists twelve
  (`X-authentik-username`, `-groups`, `-entitlements`, `-email`, `-name`, `-uid`, `-jwt`,
  `-meta-jwks`, `-meta-outpost`, `-meta-provider`, `-meta-app`, `-meta-version`). In the
  deployed outpost code `X-authentik-uid` is the OIDC `sub` and `X-authentik-jwt` the raw
  token, verifiable against the JWKS URI in `X-authentik-meta-jwks`. Domain-level mode needs
  **no new provider** for another host under `zimmermann.sh`, but cannot apply per-app
  policies. The OIDC alternative (Hermes precedent: public client, PKCE) yields the same
  `sub` (default subject mode "Based on the Hashed User ID").
- **Alertmanager** can *deliver* a request (Pushover `url`/`url_title` are templated per
  notification) but cannot *close* one: the Pushover notifier sends no `callback`, discards the
  `receipt`, defaults to `priority=2` while firing, re-pages every `repeat_interval` and sends a
  "resolved" message (`send_resolved: true`) when the alert ends. A one-shot request also
  waits `group_wait` (30 s at the root) and is resolved by `resolve_timeout` (5 min) unless
  re-posted. No time intervals are configured in the repo, so no quiet hours on this path;
  Pushover's own quiet hours downgrade priority 0 to −1 and are bypassed by 1 and 2.
- **MCP** tool-call timeout of the Claude.ai connector: **not documented** by Anthropic
  (Help Center and platform docs carry no number; the official tracker has a user report of
  60 s without an Anthropic answer). Hermes's `mcp_servers.<name>.timeout` is documented as the
  tool-call timeout and set to `60` in this repo. The MCP spec only says implementations
  SHOULD time out and SHOULD enforce a maximum. The non-blocking tool the map already settled
  on is the only design these numbers admit.

---

## 1. Pushover

Sources: [Pushover Message API](https://pushover.net/api),
[Receipt and Callback API](https://pushover.net/api/receipts).

### 1.1 Emergency priority (`priority=2`)

- "To send an emergency-priority notification, the `priority` parameter must be set to `2` and
  the `retry` and `expire` parameters must be supplied."
- `retry`: "how often (in seconds) the Pushover servers will send the same notification to the
  user", "a value of at least `30` seconds between retries".
- `expire`: "how many seconds your notification will continue to be retried for (every `retry`
  seconds). If the notification has not been acknowledged in `expire` seconds, it will be
  marked as expired and will stop being sent to the user. Note that the notification is still
  shown to the user after it is expired, but it will not prompt the user for acknowledgement.
  This parameter must have a maximum value of at most `10800` seconds (3 hours), though the
  total number of retries will be capped at 50 regardless of the `expire` parameter."
- "When your application sends an emergency-priority notification, our API will respond with a
  `receipt` value" — "a 30 character string containing the character set `[A-Za-z0-9]`".
- Optional `tags` (comma-separated) are stored with the receipt for `cancel_by_tag`.
- `ttl` "is ignored for messages with a `priority` value of `2`".

### 1.2 Receipts API

- `GET https://api.pushover.net/1/receipts/<receipt>.json?token=<app token>`, "no faster than
  once every 5 seconds", usable "up to 1 week after your notification has been received".
- Fields: `status` (1), `acknowledged` (1/0), `acknowledged_at` (Unix timestamp or 0),
  `acknowledged_by` ("the user key of the user that first acknowledged"),
  `acknowledged_by_device` ("the device name of the user that first acknowledged"),
  `last_delivered_at`, `expired` (1/0), `expires_at`, `called_back` (1/0), `called_back_at`.
- Cancel early: `POST https://api.pushover.net/1/receipts/<receipt>/cancel.json` with `token`;
  or `POST https://api.pushover.net/1/receipts/cancel_by_tag/<tag>.json`.

### 1.3 Callback

- "Rather than periodically polling our receipts API, you may also include a `callback`
  parameter when submitting your emergency notification. This must be a URL (HTTP or HTTPS)
  that is reachable from the Internet that our servers will call out to as soon as the
  notification has been acknowledged."
- Pushover submits a **POST** with: `receipt`, `acknowledged=1`, `acknowledged_at`,
  `acknowledged_by` (user key), `acknowledged_by_device` (device name).
- "If our API servers do not receive a successful (2xx) HTTP response from your callback URL,
  we will retry again in one minute."
- **No signature, shared secret, user agent or source-IP range is documented.** The receiver
  therefore cannot authenticate the POST by its content. Two verification options follow from
  the documented API: (a) treat the callback as a wake-up and confirm state with
  `GET /1/receipts/<receipt>.json?token=…` before acting; (b) put an unguessable per-request
  token into the callback URL itself (the `callback` value is under the sender's control) and
  reject anything else. Both can be combined; (a) alone already makes a forged POST harmless.
- The callback URL must be reachable **without** an authentik session. On the MCP bridge host
  that is the case today (`chain-standard`, bearer validation in the pod —
  `kubernetes/applications/iot-mcp-bridge/base/ingress-route.yaml`).

### 1.4 `url` / `url_title` and opening links from the app

- "The Pushover device clients automatically turn URLs found in message bodies into clickable
  links that open in the device's browser (or whichever application is configured to handle
  them)."
- Supplementary URL: "This URL will be passed directly to the device client, with a URL title of
  the supplied title (defaulting to the URL itself if no title given)." "When the user taps on
  the notification in Pushover to expand it, the URL will be shown below it with the supplied
  `url_title` parameter."
- The `url` parameter is part of the general message parameters; the docs attach no priority
  condition to it, so a **normal-priority (0) message carries the link** just as an emergency
  one does. Only `ttl` and the receipt/callback machinery are priority-dependent.
- Limits: "Supplementary URLs are limited to `512` characters, and URL titles to `100`
  characters." Messages: `1024` UTF-8 characters, title `250`.
- App-specific URL schemes (`twitter://`-style) work but are "not recommended … in public
  plugins, websites, and apps" because of platform differences; irrelevant for a private page.
- `html=1` switches on Pushover's limited HTML subset for the message body (the API page lists
  the supported tags); Alertmanager's `html: true` maps to exactly this parameter.

### 1.5 TTL

- "The `ttl` parameter specifies a Time to Live in seconds, after which the message will be
  automatically deleted from the devices it was delivered to." "The `ttl` value must be a
  positive number of seconds, and is counted from the time the message is received by our
  API." Ignored for `priority=2`; needs app version ≥ 4.0; expired notifications on iOS may
  linger until the next message arrives.

### 1.6 Quiet hours and priorities

- Priority 0: "If a user has quiet hours set and your message is received during those times,
  your message will be delivered as though it had a priority of `-1`."
- Priority 1: "high priority messages that bypass a user's quiet hours."
- Priority 2: "similar to high-priority notifications, but they are repeated until the
  notification is acknowledged by the user."
- "Specifying a message priority does not affect queueing or routing priority and only affects
  how device clients display them."

### 1.7 Limits and rate limits

- "Each account is permitted to send `10,000` messages per month for free, with all applications
  belonging to that user sharing the monthly quota." Over quota: `429` for all applications.
  Headers `X-Limit-App-Limit`, `X-Limit-App-Remaining`, `X-Limit-App-Reset` ("for historical
  reasons, the headers refer to 'app' limits but this is now representing the limit for the
  entire user or team"); also `GET /1/apps/limits.json?token=…`.
- "Do not create more than 2 concurrent HTTP requests (TCP connections) to our API, or we may
  do rate limiting on our side." Retries of an emergency notification are Pushover-side
  re-deliveries of one message, not new API calls by the application.
- Every 4xx returns `status != 1` with an `errors` array; retrying a 4xx "will not succeed no
  matter how many times you retry it".

---

## 2. Discord

Sources (docs.discord.com, backed by
[discord/discord-api-docs](https://github.com/discord/discord-api-docs)):
[Interactions overview](https://docs.discord.com/developers/interactions/overview),
[Receiving and responding](https://docs.discord.com/developers/interactions/receiving-and-responding),
[Components reference](https://docs.discord.com/developers/components/reference),
[Message resource](https://docs.discord.com/developers/resources/message),
[Guild member object](https://docs.discord.com/developers/resources/guild),
[OAuth2 bot flow](https://docs.discord.com/developers/topics/oauth2).
Hermes: [Discord messaging docs](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/messaging/discord.md).

### 2.1 Second application, bot token, no gateway

- Adding a bot to a guild is "a special server-less and callback-less OAuth2 flow": an
  authorize URL with `scope=bot` (plus `permissions`); "they'll be prompted to add the bot to a
  guild in which they have proper permissions. On acceptance, the bot will be added."
- `POST /channels/{channel.id}/messages`: "When operating on a guild channel, the current user
  must have the `SEND_MESSAGES` permission." The request body takes `components` ("Components
  to include with the message") and `flags` (`IS_COMPONENTS_V2 = 1 << 15` for fully
  component-driven messages). Content is limited to 2000 characters.
- No primary source requires a Gateway session for REST calls. The gateway docs say "In *most*
  cases, performing REST operations on Discord resources can be done using the HTTP API rather
  than the Gateway API", and the interactions overview describes HTTP-only apps as the reason
  the endpoint exists. Hermes's docs state the same from the other side: "Discord REST and the
  Gateway WebSocket are separate transports."
- `PATCH /channels/{channel.id}/messages/{message.id}`: "The fields `content`, `embeds`, `flags`
  and `components` can be edited by the original message author." So the posting bot can
  disable or remove its buttons once the request is decided or expired.

### 2.2 Components

- Button: `type: 2`, styles 1 Primary, 2 Secondary, 3 Success, 4 Danger, 5 Link, 6 Premium;
  `label` "max 80 characters"; `custom_id` "1-100 characters"; optional `disabled`.
- "Non-link and non-premium buttons **must** have a `custom_id`"; "Link buttons do not send an
  interaction to your app when clicked" (same for premium buttons).
- "custom_id … is returned in the interaction payload sent when a user interacts with the
  component." Must be unique per message.
- Action row: "Up to 5 contextually grouped buttons"; "Messages allow up to 40 total
  components."

### 2.3 Receiving the click: Interactions Endpoint URL

- "When a user interacts with your app, you have the option for your app to receive
  interactions in two mutually-exclusive ways: WebSocket-based Gateway connection; HTTP via
  outgoing webhooks. By default your app will receive interactions via a Gateway connection,
  but you can opt-in to HTTP-based interactions by adding a **Interactions Endpoint URL** to
  your app's settings." The URL is set per application on the General Information page.
- Before Discord accepts the URL the endpoint must (1) answer a `PING` (`type: 1`) POST with
  `200` and a `PONG` (`type: 1`) body and (2) validate the headers `X-Signature-Ed25519` and
  `X-Signature-Timestamp` against the application's public key: "you **must validate the
  request each time you receive an interaction**. If the signature fails validation, your app
  should respond with a `401` error code." "If you fail the validation, we will remove your
  interactions URL and alert you via email and System DM."
- Interaction object: `id`, `application_id`, `type`, `data` (for components: `custom_id`,
  `component_type`), `guild_id`, `channel_id`, `member` / `user`, `token`, `message` ("For
  components or modals triggered by components, the message they were attached to").
- "`member` is sent when the interaction is invoked in a guild, and `user` is sent when invoked
  in a DM." The guild member object carries `user` ("the user this guild member represents";
  the omission of `user` applies only to `MESSAGE_CREATE`/`MESSAGE_UPDATE` gateway events) and
  `permissions` ("total permissions of the member in the channel, including overwrites,
  returned when in the interaction object"). The user object's `id` is the snowflake. **The
  clicking user's id is therefore in the payload**, and it can be compared with the single
  allowed id Hermes already pins (`DISCORD_ALLOWED_USERS` in
  `kubernetes/applications/hermes/base/values.yaml`).

### 2.4 Response deadline and deferral

- "Interaction `tokens` are valid for **15 minutes** and can be used to send followup messages
  but you **must send an initial response within 3 seconds of receiving the event**. If the 3
  second deadline is exceeded, the token will be invalidated."
- Callback types: 4 `CHANNEL_MESSAGE_WITH_SOURCE`; 5 `DEFERRED_CHANNEL_MESSAGE_WITH_SOURCE`
  ("ACK an interaction and edit a response later, the user sees a loading state");
  6 `DEFERRED_UPDATE_MESSAGE` ("For components, ACK an interaction and edit the original
  message later; the user does not see a loading state"); 7 `UPDATE_MESSAGE` ("For components,
  edit the message the component was attached to"). 6 and 7 are "Only valid for
  component-based interactions."
- The original response is edited via
  `PATCH /webhooks/{application.id}/{interaction.token}/messages/@original`.

### 2.5 Can `lares-agent` host the endpoint while Hermes holds the gateway?

- Discord: the two delivery modes are mutually exclusive **per application**; setting the
  Interactions Endpoint URL moves *all* of that application's interactions to HTTP.
- Hermes: "Hermes automatically registers installed skills as **native Discord Application
  Commands**"; "Skills are registered during bot startup alongside built-in commands like
  `/model`, `/reset`, and `/bg`"; `DISCORD_COMMAND_SYNC_POLICY` controls the startup
  `tree.sync()`; it runs "through the full messaging gateway".
- Consequence: an endpoint on `lares-agent` would divert Hermes's slash-command interactions
  to the gate's HTTP endpoint, where Hermes cannot see them. A **second application** (own bot
  user, own token, own public key, invited into the guild with `SEND_MESSAGES` on the target
  channel) keeps the two apart. No documented cap on bot users per guild was found (see
  section 6).

---

## 3. Authentik (2026.8.2)

Sources: [Proxy provider](https://docs.goauthentik.io/add-secure-apps/providers/proxy/),
[Forward auth](https://docs.goauthentik.io/add-secure-apps/providers/proxy/forward_auth),
[Traefik template](https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik),
[OAuth 2.0 provider](https://docs.goauthentik.io/add-secure-apps/providers/oauth2/),
outpost source at the deployed tag
[`internal/outpost/proxyv2/application/mode_common.go`](https://github.com/goauthentik/authentik/blob/version/2026.8.2/internal/outpost/proxyv2/application/mode_common.go),
[`authentik/common/oauth/constants.py`](https://github.com/goauthentik/authentik/blob/version/2026.8.2/authentik/common/oauth/constants.py),
[Traefik ForwardAuth reference](https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/forwardauth/).

### 3.1 Header names the outpost sets

Docs (2026.8), "Headers sent to upstream applications": `X-authentik-username` ("Username of the
currently logged in user"), `X-authentik-groups` ("Groups the user is a member of, separated by
pipes"), `X-authentik-entitlements`, `X-authentik-email`, `X-authentik-name`,
`X-authentik-uid` ("Hashed identifier of the currently logged in user"), plus
`X-authentik-meta-outpost`, `-meta-provider`, `-meta-app`, `-meta-version`.

Code at tag `version/2026.8.2` (`getHeaders`):

```go
headers["X-authentik-username"] = c.PreferredUsername
headers["X-authentik-groups"]   = strings.Join(c.Groups, "|")
headers["X-authentik-email"]    = c.Email
headers["X-authentik-name"]     = c.Name
headers["X-authentik-uid"]      = c.Sub
headers["X-authentik-jwt"]      = c.RawToken
headers["X-authentik-meta-jwks"] = a.endpoint.JwksUri
```

So `X-authentik-uid` **is the OIDC `sub`** of the outpost's own token, and `X-authentik-jwt` is
that raw token; the JWKS to verify it is named in `X-authentik-meta-jwks`. The 2026.8 docs list
`X-authentik-jwt`/`-meta-jwks` only in the Traefik template, not in the header table.

### 3.2 `authResponseHeaders` on the Traefik middleware

- authentik's Traefik template: `forwardAuth.address: …/outpost.goauthentik.io/auth/traefik`,
  `trustForwardHeader: true`, `authResponseHeaders:` `X-authentik-username`,
  `X-authentik-groups`, `X-authentik-entitlements`, `X-authentik-email`, `X-authentik-name`,
  `X-authentik-uid`, `X-authentik-jwt`, `X-authentik-meta-jwks`, `X-authentik-meta-outpost`,
  `X-authentik-meta-provider`, `X-authentik-meta-app`, `X-authentik-meta-version`.
- Traefik: `authResponseHeaders` is the "List of headers to copy from the authentication server
  response and set on forwarded request, replacing any existing conflicting headers." A non-2xx
  auth response is returned to the client as is.
- Repo: `kubernetes/components/ingress-controller/base/middlewares.yaml`, middleware
  `authentik`, has `address`, `trustForwardHeader: true`, `maxResponseBodySize` — and **no
  `authResponseHeaders`**. That is the whole reason no identity reaches any app today.
  `chain-mfa-auth` = `chain-pre-auth` → `authentik` → `chain-post-auth`; `strip-headers` in the
  post-auth chain blanks `X-Forwarded-*`/`Cf-*`/`X-Real-Ip` only, `strip-cookies` removes the
  authentik cookies. Neither touches `X-authentik-*`, so adding the list to the `authentik`
  middleware is sufficient to deliver identity to an upstream.
- Spoofing: Traefik *replaces* conflicting request headers with the auth server's values, and
  the outpost sets every `X-authentik-*` header on each authenticated request; a client cannot
  smuggle its own `X-authentik-uid` past the chain. (Inference from the two statements above,
  not a sentence in either doc.)

### 3.3 Domain-level mode vs. a provider of its own

- "Domain-level mode works for multiple applications under the same parent domain. Set
  Authentication URL to the URL used for authentication, and Cookie domain to the parent
  domain shared by the protected applications." "You do not need to configure an application
  and provider in authentik for each application domain." "Users do not need to authorize each
  application separately."
- "Domain-level forward auth cannot enforce different application-level authorization rules
  for each protected application. Use single-application mode when each application needs its
  own policies, bindings, or authorization behavior."
- Repo: provider `forward-auth-proxy`, `mode: forward_domain`, cookie domain `zimmermann.sh`
  in prod (`overlays/prod/kustomization.yaml`), bound to group `platform-admins`
  (`base/blueprints/forward-auth.yaml`). A new host such as an approval page under
  `zimmermann.sh` is served by this provider **without a new provider**, inheriting the
  `platform-admins` gate; only a Traefik route with `chain-mfa-auth` is needed. A stricter
  per-page policy would need single-application mode, i.e. its own provider.
- Paths that must stay open on a forward-auth host (Pushover callback, `/mcp` for the bearer
  clients) can be carved out either in Traefik (separate router, higher priority,
  `chain-standard`) or in authentik: "To allow unauthenticated requests to specific paths or
  URLs, use the Unauthenticated Paths or Unauthenticated URLs field on the proxy provider. Each
  new line is interpreted as a regular expression … A pattern that fails to compile is
  skipped, and a warning is written to the outpost logs." The MCP bridge host today runs on
  `chain-standard` precisely because "claude.ai cannot do interactive login".

### 3.4 OIDC client of the bridge's own

- "Confidential clients authenticate to the token endpoint using a client ID and client secret
  or another supported client authentication method. Public clients, which cannot securely
  store a client secret, should use the authorization code flow with PKCE."
- Precedent `base/blueprints/hermes.yaml`: `client_type: public`, `client_id:
  hermes-dashboard`, `grant_types: [authorization_code, refresh_token]`, scopes
  `openid`/`email`/`profile`, bound to `platform-admins`. The bridge already owns a
  **confidential** provider `iot-mcp-bridge` (explicit consent, `offline_access`, 1 h access /
  30 d refresh) for the Claude.ai connector — `base/blueprints/iot-mcp-bridge.yaml`.
- Subject: `sub_mode` defaults to `SubModes.HASHED_USER_ID` ("Based on the Hashed User ID");
  the other modes are user ID, user UUID, username, e-mail, UPN. With the default, the `sub`
  an OIDC login yields **equals `X-authentik-uid`** from forward-auth (both are `sub` of a
  token for the same user), so the two identity paths agree on the identifier to record.
- Known quirk from this repo's memory: the `profile` scope mapping emits `groups`.

---

## 4. Alertmanager

Sources: [Configuration](https://prometheus.io/docs/alerting/latest/configuration/),
[Alerts API](https://prometheus.io/docs/alerting/latest/alerts_api/),
[`template/default.tmpl`](https://github.com/prometheus/alertmanager/blob/main/template/default.tmpl),
[`notify/pushover/pushover.go`](https://github.com/prometheus/alertmanager/blob/main/notify/pushover/pushover.go),
[`notify/pushover/config.go`](https://github.com/prometheus/alertmanager/blob/main/notify/pushover/config.go);
repo `kubernetes/applications/prometheus/base/values.yaml`.

### 4.1 Routing timers

- `group_wait` (default 30s): "How long to wait before sending the first notification for a new
  group of alerts." `group_interval` (5m): wait "before sending subsequent notifications for
  an existing group". `repeat_interval` (4h): "How long to wait before repeating the last
  notification"; "should be a multiple of the group_interval", otherwise rounded up.
- Repo root route: `group_by: [alertname, job]`, `group_wait: 30s`, `group_interval: 1m`,
  `repeat_interval: 6h`; a dedicated route may override each (including `group_wait: 0s`).
- `resolve_timeout` (global, default 5m; repo 5m): "the default value used by alertmanager if
  the alert does not include EndsAt, after this time passes it can declare the alert as
  resolved if it has not been updated."
- `mute_time_intervals` / `active_time_intervals`: none are configured in the repo, so this
  path has **no quiet hours** of its own.

### 4.2 Pushover receiver

- Fields and defaults (`config.go`): `send_resolved: true`, `title`/`message`/`url` from the
  `pushover.default.*` templates, `url_title` (YAML `url_title`, present in code, **absent from
  the configuration docs**), `device`, `sound`, `priority: '{{ if eq .Status "firing" }}2{{
  else }}0{{ end }}'`, `retry: 1m`, `expire: 1h`, `ttl`, `html: false`, `monospace: false`.
- `pushover.default.url` = `{{ .ExternalURL }}/#/alerts?receiver={{ .Receiver | urlquery }}`;
  `pushover.default.title` = `[FIRING:n] <group labels> (...)`.
- The notifier truncates title to 250, message to 1024 and URL to 512 runes, always sends
  `retry`/`expire`, and sends **no `callback`** and keeps **no `receipt`**: the Pushover
  response is only checked for retry-worthiness. Alertmanager therefore cannot learn about an
  acknowledgement.
- Observation, outside this ticket: the repo's `*-warning` receivers set no `priority`, so they
  inherit the emergency default (`2`, retry 1m, expire 1h) while firing; only the `-critical`
  receivers pin `priority: "1"` and `watchdog` pins `-1`.

### 4.3 One-shot request through the API

- `POST /api/v2/alerts` with `labels`, `annotations`, optional `startsAt`/`endsAt`
  (RFC 3339). "If omitted, Alertmanager sets `endsAt` to the current time + `resolve_timeout`."
  "Clients are expected to re-send firing alerts to the Alertmanager at regular intervals until
  the alert is resolved", and resolved alerts for about five more minutes.
- Consequences for a one-shot approval request: the page is delayed by `group_wait`; the
  request is re-paged every `repeat_interval` while the alert is kept alive and dropped after
  `resolve_timeout` if it is not; with `send_resolved` on, the end of the alert produces a
  second (priority-0) Pushover message; the `url` can carry the approval page (annotation
  templated per *notification*, i.e. per group — fine while `group_by` isolates one request per
  group). Identity of the acknowledger, the receipt and the callback are out of reach on this
  path; a direct Pushover call from the gate has all three.

---

## 5. MCP tool-call timeouts

Sources: [Get started with custom connectors using remote MCP](https://support.claude.com/en/articles/11175166-get-started-with-custom-connectors-using-remote-mcp),
[MCP connector (Claude API)](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector),
[anthropics/claude-ai-mcp#115](https://github.com/anthropics/claude-ai-mcp/issues/115),
[MCP spec 2025-06-18, Lifecycle › Timeouts](https://modelcontextprotocol.io/specification/2025-06-18/basic/lifecycle#timeouts),
[Hermes MCP docs](https://github.com/NousResearch/hermes-agent/blob/main/website/docs/user-guide/features/mcp.md),
repo `kubernetes/applications/hermes/base/config/config.yaml`.

- Claude.ai custom connector: the Help Center article states that Claude "connects to your
  remote MCP server from Anthropic's cloud infrastructure" and mentions static OAuth client
  id/secret as an option, but **no tool-call timeout**. The platform MCP-connector page (API
  side) has none either. Anthropic's tracker carries a user report that the default is 60 s
  (issue "Allow increasing the default timeout", no Anthropic reply). **Unverified.**
- MCP spec: "Implementations SHOULD establish timeouts for all sent requests … SHOULD issue a
  cancellation notification … SHOULD always enforce a maximum timeout, regardless of progress
  notifications." No number.
- Hermes: `mcp_servers.<name>.timeout` — "Tool call timeout"; `connect_timeout` separately
  bounds the `initialize` handshake. Repo: `lares.timeout: 60`.
- Net: the tool has to return within tens of seconds on every client; the map's settled
  non-blocking `request_knx_write` → `get_write_request` pair is the only shape these limits
  admit.

---

## 6. Not verified from a primary source

- Pushover callback origin (IP ranges, user agent) and any transport-level authentication:
  not documented; treat the callback as unauthenticated (section 1.3).
- Pushover's exact list of supported HTML tags was not captured verbatim; the API page holds it.
- Claude.ai connector tool-call timeout: no Anthropic statement found (section 5).
- Discord: an explicit statement that a guild may host any number of bot users was not found;
  the bot-authorization flow documents adding bots without a stated cap.
- The claims inside `X-authentik-jwt` (`types.Claims` in the outpost) were not read; only the
  header assignments were.
