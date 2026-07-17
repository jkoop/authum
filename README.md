# authum

authum is a Traefik ForwardAuth server that logs users in with username/password and enforces an in-memory ACL so each site gets identity headers and a host-scoped session cookie.

## Run

```bash
export AUTHUM_DOMAIN=login.example.com
export AUTHUM_ADMIN_USER=admin
export AUTHUM_ADMIN_PASSWORD=changeme
export AUTHUM_LISTEN=0.0.0.0:8080
export AUTHUM_DB_PATH=authum.db   # optional

zig0.16 build run
```

## Traefik

Point ForwardAuth at authum’s verify endpoint; proxy the login host to authum as a normal backend. Example (Traefik v3 labels sketch):

```yaml
# Protected app
labels:
  - traefik.http.middlewares.authum.forwardauth.address=http://authum:8080/auth/verify
  - traefik.http.middlewares.authum.forwardauth.authResponseHeaders=Remote-User,Remote-User-Id,Remote-User-Name
  - traefik.http.routers.app.middlewares=authum

# Login UI (AUTHUM_DOMAIN) — no ForwardAuth; route to the authum service
```

Register each app in the admin **Sites** TSV (`site_id`, `host`, identity header names) and allow paths in the **ACL** TSV. After login, users bounce through `https://{host}/_authum/login` so each site can set its own cookie (same session id everywhere).
