-- forward-auth: centralized external authentication for Kong OSS.
--
-- Flow (access phase):
--   1. Strip any client-supplied identity headers (anti-spoofing).
--   2. Require an Authorization header.
--   3. Verify the token against the external auth service (araquanid),
--      caching the result per-token to avoid hammering it.
--   4. Inject trusted X-User-* headers for the upstream service.
--
-- Kong never validates the JWT itself; araquanid remains the single source
-- of truth for authentication and authorization.

local http  = require "resty.http"
local cjson = require "cjson.safe"

local kong = kong
local ngx  = ngx

local ForwardAuth = {
  -- Run after credential-extraction plugins but before request transforms.
  PRIORITY = 1000,
  VERSION  = "1.0.0",
}

-- Calls the auth service. Returns a result table for *definitive* outcomes
-- (authenticated / 401 / 403) which is safe to cache, or (nil, err) for
-- *transient* failures (unreachable, bad body) which must NOT be cached.
local function verify_token(conf, auth_header)
  local client = http.new()
  client:set_timeout(conf.timeout)

  local res, err = client:request_uri(conf.auth_url, {
    method  = conf.method,
    headers = { ["Authorization"] = auth_header },
  })

  if not res then
    return nil, "auth service unreachable: " .. tostring(err)
  end

  if res.status == 200 then
    local identity = cjson.decode(res.body)
    if type(identity) ~= "table" then
      return nil, "invalid auth service response body"
    end
    return { authenticated = true, identity = identity }
  end

  if res.status == 401 or res.status == 403 then
    return { authenticated = false, status = res.status }
  end

  return nil, "unexpected auth service status: " .. tostring(res.status)
end

-- Coerce a value (string, number, or array) into a header string.
local function as_string(value)
  if value == nil then
    return nil
  end
  if type(value) == "table" then
    return table.concat(value, ",")
  end
  return tostring(value)
end

local function set_or_clear(name, value)
  value = as_string(value)
  if value == nil then
    kong.service.request.clear_header(name)
  else
    kong.service.request.set_header(name, value)
  end
end

function ForwardAuth:access(conf)
  -- (1) Anti-spoofing: never let a client inject its own identity headers.
  local identity_headers = {
    conf.header_id, conf.header_email, conf.header_role, conf.header_permissions,
  }
  for _, header in ipairs(identity_headers) do
    kong.service.request.clear_header(header)
  end

  -- (2) An Authorization header is mandatory.
  local auth_header = kong.request.get_header("Authorization")
  if not auth_header then
    return kong.response.exit(401, { message = "Missing Authorization header" })
  end

  -- (3) Verify (cached per token; transient errors are not cached).
  local cache_key = "forward_auth:" .. ngx.md5(auth_header)
  local result, err = kong.cache:get(cache_key, { ttl = conf.cache_ttl },
                                     verify_token, conf, auth_header)

  if err then
    kong.log.err("forward-auth: ", err)
    return kong.response.exit(502, { message = "Authentication service unavailable" })
  end

  if not result.authenticated then
    return kong.response.exit(result.status, { message = "Unauthorized" })
  end

  -- (4) Inject trusted identity headers for the upstream service.
  local id = result.identity
  set_or_clear(conf.header_id,          id.id)
  set_or_clear(conf.header_email,       id.email)
  set_or_clear(conf.header_role,        id.role)
  set_or_clear(conf.header_permissions, id.permissions)
end

return ForwardAuth
