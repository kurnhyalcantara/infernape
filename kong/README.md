# Kong Configuration

Kong runs in **DB mode** (backed by the dedicated `koer-kong-db` Postgres) so that
**Kong Manager OSS** (`http://localhost:8002`) can read *and* write configuration.

## Layout

```
kong/
├── kong.yaml                 # decK baseline: services, routes, plugins (tag: baseline)
├── plugins/
│   └── forward-auth/         # custom external-auth plugin (Lua)
│       ├── handler.lua       # access phase: strip → verify → inject X-User-* headers
│       └── schema.lua        # plugin config (auth_url, timeout, cache_ttl, header names)
└── README.md
```

## Configuration strategy (Hybrid)

- **Git is the baseline source of truth.** `kong.yaml` is applied on startup by the
  one-shot `kong-deck` container via `deck gateway sync --select-tag baseline`.
- **Developers may extend via Kong Manager.** Because decK is run with
  `--select-tag baseline`, it only manages entities tagged `baseline`. Anything you
  create ad-hoc in Kong Manager is left untouched on re-sync.
- Re-apply the baseline after editing `kong.yaml`:

  ```bash
  make kong-sync
  ```

> Promote a useful experiment from Kong Manager into the baseline by adding it to
> `kong.yaml` with `tags: [baseline]` and running `make kong-sync`.

## The forward-auth plugin

Kong OSS has no first-class forward-auth plugin (OIDC and Request-Callout are
Enterprise-only), so this minimal Lua plugin implements the external-auth pattern:

1. Strips any client-supplied `X-User-*` headers (anti-spoofing).
2. Requires an `Authorization` header (else `401`).
3. Calls the auth service (`config.auth_url`, default araquanid `/auth/verify`),
   caching the result per-token for `config.cache_ttl` seconds.
4. On `200`, injects trusted `X-User-ID`, `X-User-Email`, `X-User-Role`,
   `X-User-Permissions` headers for the upstream. On `401/403`, rejects.

It is mounted into the stock Kong image (no rebuild) and enabled with
`KONG_PLUGINS=bundled,forward-auth`. After editing the Lua, restart Kong:

```bash
docker compose restart kong
```

## Why env vars instead of `kong.conf`

Kong is configured entirely through `KONG_*` environment variables in
`docker-compose.yml` — the idiomatic, single-source-of-truth approach for
containers. A `kong.conf` file is the equivalent alternative (mount it and set
`KONG_DECLARATIVE_CONFIG`/`-c`), but it would duplicate what Compose already owns.
