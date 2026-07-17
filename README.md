# authum

authum is a Traefik ForwardAuth server that logs users in with username/password and enforces an in-memory ACL so each site gets identity headers and a host-scoped session cookie.

## Run

```yaml
services:
  authum:
    build: .
    ports:
      - "8080:8080"
    environment:
      AUTHUM_DOMAIN: login.example.com
      AUTHUM_ADMIN_USER: admin
      AUTHUM_ADMIN_PASSWORD: changeme
      AUTHUM_DB_PATH: /data/authum.db
    volumes:
      - authum-data:/data

volumes:
  authum-data:
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

Register each app in the admin **Sites** TSV and allow paths in the **ACL** TSV. After login, users bounce through `https://{host}/_authum/login` so each site can set its own cookie (same session id everywhere).

## Sites TSV

| Column | Meaning |
|--------|---------|
| `site_id` | Stable id referenced by ACL rows |
| `host` | Hostname only (no `https://`) |
| `user_header` / `user_id_header` / `user_name_header` | Response headers Traefik must forward |

Example:

```tsv
site_id	host	user_header	user_id_header	user_name_header
jellyfin	media.example.com	Remote-User	Remote-User-Id	Remote-User-Name
```

## ACL TSV

First matching row wins; no match means deny.

| Column | Meaning |
|--------|---------|
| `user` | `*` (anyone), `id:username` (match on numeric id; username is a label), or `@group` |
| `site_id` | Sites id or `*` |
| `path` | RE2-style regex against the request path |
| `method` | HTTP method or `*` |
| `effect` | `allow` or `deny` |

Example:

```tsv
user	site_id	path	method	effect
*	files	(?i)\.pdf$	*	deny
@friends	jellyfin	^/	*	allow
1:admin	*	^/	*	allow
```

Use `^/…` when you want prefix-style matching. Renaming a user does not break `id:username` rows (id is what matches).

Create groups and memberships in the admin UI, then reference them as `@friends` instead of duplicating a row per person.

## LDAP (Jellyfin)

Set `AUTHUM_LDAP_LISTEN` (for example `0.0.0.0:3893`) to enable a minimal LDAP server over the same users/groups. Optional `AUTHUM_LDAP_BASE_DN` defaults to `dc=authum,dc=local`.

Suggested Jellyfin LDAP plugin settings:

| Field | Value |
|-------|--------|
| LDAP Server | `ldap://authum:3893` |
| Base DN | `dc=authum,dc=local` |
| Bind User | empty (anonymous search) or `uid=admin,ou=people,dc=authum,dc=local` |
| Search Filter | `(uid=*)` or `(memberof=cn=friends,ou=groups,dc=authum,dc=local)` |
| Search Attributes | `uid` |
| Uid / Username Attribute | `uid` |

Tree layout: `ou=people,…` (`uid=<username>`) and `ou=groups,…` (`cn=<group>` with `member` / `memberOf`). Disabled users are omitted.

## Discord login

Set both `AUTHUM_DISCORD_CLIENT_ID` and `AUTHUM_DISCORD_CLIENT_SECRET` to show **Log in with Discord**. Redirect URL:

`https://{AUTHUM_DOMAIN}/login/discord/callback`

New Discord accounts are created **disabled**; enable them in the admin Users table before they can use sites.
