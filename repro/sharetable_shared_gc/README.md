# Known issue: a consumer's GC marks objects owned by the sharetable heap

A service that caches a `sharetable` reference in the **array part** of a plain
table makes its own garbage collector mark — and fully traverse — the shared
subgraph owned by the matrix Lua state. The consumer's GC accounting is then
inflated by the whole shared payload, its next GC threshold is scaled up
accordingly, and automatic collection effectively stops keeping up.

## Root cause

`skynet/3rd/lua/lgc.c:520`, in `traversearray()`:

```c
GCObject *o = gcvalarr(h, i);
if (o != NULL && iswhite(o)) {
  marked = 1;
  reallymarkobject(g, o);
}
```

Sharetable objects are created in the matrix state and tagged `G_SHARED` by
`makeshared()`. Every sweep path skips them — `sweeplist()`, `sweep2old()` and
`sweepgen()` all start with `if (isshared(curr)) continue`. Because they are
never swept, their colour is never flipped back and **stays white forever**.

So `iswhite(o)` being true does *not* mean "`o` belongs to this heap". That is
exactly why `lgc.h:127` defines

```c
#define ispurewhite(x)  (iswhite(x) && !isshared(x))
```

and why every other marking site uses `ispurewhite()`, or the `valiswhite()`
macro that wraps it. `traversearray()` hand-rolls its marking loop and dropped
the `!isshared` half.

Only the **array part** is affected: the hash part is marked through
`markvalue()` → `valiswhite()` → `ispurewhite()`, which is correct.

```lua
local cache = { shared }        -- hits the bug
local cache = { cfg = shared }  -- correct, goes through valiswhite()
```

`reallymarkobject()` also does `g->GCmarked += objsize(o)`, so the consumer's
`GCmarked` absorbs the shared payload. `setpause()` (`lgc.c:1125`) derives the
next threshold from it:

```c
l_mem threshold = applygcparam(g, PAUSE, g->GCmarked);
```

which pushes the consumer's next collection far into the future.

Beyond the accounting damage, `reallymarkobject()` writes to memory owned by
another Lua state: it changes the shared object's `marked` byte and overwrites
its `gclist` field to link it into *this* heap's gray list. With several worker
threads collecting concurrently, that is an unsynchronised write to a field
shared by all of them.

## Fix

```c
-if (o != NULL && iswhite(o)) {
+if (o != NULL && ispurewhite(o)) {
```

## Reproduce

The runner only discovers `test/cases/test_*.lua`, so this lives outside the
test suite and CI never runs it. To trigger it manually:

```sh
make build
cd skynet && ./skynet ../repro/sharetable_shared_gc/config
```

Measured on the current submodule (Lua 5.5), 200k shared items and 300k garbage
tables:

| build | memory growth under automatic GC |
|-------|----------------------------------|
| current (`iswhite`)     | **38554 KB** — also trips skynet's `Memory warning 33.41 M` |
| patched (`ispurewhite`) | **4 KB** |

Needs roughly 100MB of free RAM.
