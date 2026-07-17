# Agent instructions

## Toolchain

When instructions, snippets, READMEs, or other documentation refer to a `zig` command (for example `zig build`, `zig test`, `zig fmt`), invoke **`zig0.16`** instead (for example `zig0.16 build`, `zig0.16 test`, `zig0.16 fmt`). This substitution is mandatory for consistency with this project's toolchain.

Use **`zig0.16 env`** when you need the path to this toolchain’s Zig standard library (among other resolved paths)—for example when checking something against the bundled std sources.

Downloaded Zig dependencies resolve under the **global cache** from that same output (`global_cache_dir`—on Linux commonly `~/.cache/zig`, or `$XDG_CACHE_HOME/zig` when set). Packages live in hashed directories there (typically under `p/`). When debugging behaviour that comes from **`@import`** of someone else’s code, **grep or search inside `global_cache_dir` and the std lib path from `zig0.16 env`** rather than digging only inside this repo: upstream comments, READMEs, and doc comments are easiest to find that way.
