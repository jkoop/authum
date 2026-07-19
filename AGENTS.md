# Agent instructions

## Toolchain

When instructions, snippets, READMEs, or other documentation refer to a `zig` command (for example `zig build`, `zig test`, `zig fmt`), invoke **`zig0.16`** instead (for example `zig0.16 build`, `zig0.16 test`, `zig0.16 fmt`). This substitution is mandatory for consistency with this project's toolchain.

Use **`zig0.16 env`** when you need the path to this toolchain’s Zig standard library (among other resolved paths)—for example when checking something against the bundled std sources.

Downloaded Zig dependencies resolve under the **global cache** from that same output (`global_cache_dir`—on Linux commonly `~/.cache/zig`, or `$XDG_CACHE_HOME/zig` when set). Packages live in hashed directories there (typically under `p/`). When debugging behaviour that comes from **`@import`** of someone else’s code, **grep or search inside `global_cache_dir` and the std lib path from `zig0.16 env`** rather than digging only inside this repo: upstream comments, READMEs, and doc comments are easiest to find that way.

Local checkouts of dependencies also appear under `zig-pkg/` (gitignored). Prefer the global cache + `zig0.16 env` paths when hunting upstream docs.

## What this is

**authum** is a Traefik ForwardAuth server: username/password login, in-memory ACL + sites registry (loaded from SQLite `acl_rules` / `sites` tables; TSV is backup import/export), per-site session cookies that share one session id, and an ugly admin UI on the login domain.

## Layout

| Path | Role |
|------|------|
| [`src/main.zig`](src/main.zig) | Entry: env config, httpz listen, route registration |
| [`src/app.zig`](src/app.zig) | Shared `App` state (DB pool, ACL, sites, config), bootstrap, routes |
| [`src/config.zig`](src/config.zig) | Env: `AUTHUM_DOMAIN`, `AUTHUM_ADMIN_USER`/`PASSWORD`, `AUTHUM_LISTEN`, `AUTHUM_DB_PATH`, optional `AUTHUM_LDAP_*` |
| [`src/ldap.zig`](src/ldap.zig) / [`src/ber.zig`](src/ber.zig) | Minimal LDAP bind/search for Jellyfin (off unless `AUTHUM_LDAP_LISTEN`) |
| [`src/verify.zig`](src/verify.zig) | `GET /auth/verify` — Traefik ForwardAuth + inferred `/_authum/*` |
| [`src/web.zig`](src/web.zig) | Login domain UI: login/logout, admin, password change |
| [`src/templates.zig`](src/templates.zig) / [`src/views/`](src/views/) | ztl templates (embedded) for login/account/admin |
| [`src/db.zig`](src/db.zig) | SQLite schema, users/sessions/tickets/sites/acl_rules, legacy document migration |
| [`src/acl.zig`](src/acl.zig) / [`src/sites.zig`](src/sites.zig) | In-memory ACL/sites + TSV parse/export |
| [`src/password.zig`](src/password.zig) | Argon2id hash/verify (needs `std.Io`) |
| [`src/util.zig`](src/util.zig) | Cookies, URL helpers, Basic auth parse, username charset checks |

Dependencies: [http.zig](https://github.com/karlseguin/http.zig) (`httpz`), [zqlite.zig](https://github.com/karlseguin/zqlite.zig) (bundles SQLite amalgamation).

## Request flow (mental model)

1. Traefik calls **only** `GET /auth/verify` for protected apps (with `X-Forwarded-*`).
2. Special paths on the *original* host are inferred from `X-Forwarded-Uri`:
   - `/_authum/login` — one-time ticket → `Set-Cookie` + redirect to path
   - `/_authum/logout` — invalidate session globally + clear cookie on that host
3. `AUTHUM_DOMAIN` is a normal reverse-proxy backend to authum (login/admin HTML). Do not put the login form on app hosts if you care about password managers.
4. After form login, redirect goes to `{site.host}/_authum/login?path=…&ticket=…` so each site gets its own host-scoped cookie, all carrying the **same** session id.

## Gotchas

- **Admin is a username, not a role.** Gate is `username == AUTHUM_ADMIN_USER`. Renaming/deleting that user is refused; changing the env var without updating the DB user will lock you out of `/admin`.
- **`seedAdmin` resets the admin password** from `AUTHUM_ADMIN_PASSWORD` on every startup.
- **ACL user column is `*`, `#id`, or `@id`.** Authz matches numeric user/group ids (SQLite FKs). Renaming a user or group does not break ACL rows. Orphan group ids (deleted group cascades rules away) simply never match.
- **ACL `path` is a RE2-style regex** (via zoptia0regex), not a plain prefix. Prefer `^/api/` for prefix-like rules; e.g. `(?i)\.pdf$` to deny PDFs. Invalid patterns fail TSV load with `.invalid`.
- **ACL site column is numeric site id, not host or name.** Hostnames live in `sites`; verify looks up by host, then matches ACL on that site’s id (`*` = any site).
- **Sites hosts have no scheme.** Redirects use `https` unless `X-Forwarded-Proto` is `http`. Login `from_site` is the numeric site id.
- **Per-site cookies, shared session.** Logout anywhere deletes the session row; leftover cookies on other hosts fail verify until cleared.
- **Browser vs API:** User-Agent containing `Mozilla` → HTML login redirect on verify. Otherwise Basic auth. No CSRF anywhere (intentional).
- **httpz multipart** needs `max_multiform_count` > 0 (set in `main.zig`) or TSV file uploads silently fail to parse.
- **zqlite pool:** `acquire(io)` / `release(io)` — Conn is a value type; always release.
- **Zig 0.16 Io:** argon2, mutexes, clocks, and random go through `std.Io` (`app.io`), not old `std.time.timestamp` / `std.Thread.RwLock`.
- **TSV parse errors** return `.invalid` with a message; uploads should surface them as 400. Don’t let raw parse errors fall through to the 500 handler.
- **Usernames / group names:** `[A-Za-z0-9_]` only, and not only digits (`util.validUsername`).
- **`users.enabled` defaults on.** Discord-provisioned users start disabled; password/session/LDAP/Basic all refuse disabled accounts. Cannot disable `AUTHUM_ADMIN_USER`.
- **Discord** needs both `AUTHUM_DISCORD_CLIENT_ID` and `AUTHUM_DISCORD_CLIENT_SECRET`; redirect is `https://{AUTHUM_DOMAIN}/login/discord/callback`.
- **No Traefik config in-repo.** Downstream needs ForwardAuth → `/auth/verify` and `authResponseHeaders` (or regex) covering whatever identity header names each site defines.
- **TSV is backup.** Admin edits sites/ACL as tables; upload replaces all rows for that table.
