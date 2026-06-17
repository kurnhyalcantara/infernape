local typedefs = require "kong.db.schema.typedefs"

-- Configuration schema for the forward-auth plugin.
--
-- The plugin delegates authentication/authorization to an external auth
-- service (araquanid) and injects trusted identity headers for the upstream.
-- It never validates JWTs itself.
return {
  name = "forward-auth",
  fields = {
    { protocols = typedefs.protocols_http },
    {
      config = {
        type = "record",
        fields = {
          -- External auth service endpoint that verifies the bearer token.
          { auth_url = {
              type = "string",
              required = true,
              default = "http://araquanid:8080/auth/verify",
          } },
          -- HTTP method used to call the auth service.
          { method = {
              type = "string",
              default = "GET",
              one_of = { "GET", "POST" },
          } },
          -- Timeout (ms) for the call to the auth service.
          { timeout = { type = "number", default = 2000 } },
          -- How long (s) a verification result is cached, keyed by token.
          { cache_ttl = { type = "number", default = 30 } },
          -- Names of the trusted identity headers injected upstream.
          { header_id          = { type = "string", default = "X-User-ID" } },
          { header_email       = { type = "string", default = "X-User-Email" } },
          { header_role        = { type = "string", default = "X-User-Role" } },
          { header_permissions = { type = "string", default = "X-User-Permissions" } },
        },
      },
    },
  },
}
