# Known issue: `rawset` bypasses the read-only guard on a shared table

A `sharetable` is meant to be read-only — its memory lives in the matrix Lua
state and is mapped into every service that queried it, with no locking and no
stop-the-world. Ordinary assignment is rejected, but `rawset` overwrites an
existing key silently and successfully.

## Root cause

`rawset` reaches the table storage through a path that is missing the check:

```
rawset -> lua_rawset (lapi.c) -> aux_rawset (lapi.c)
       -> luaH_set   (skynet/3rd/lua/ltable.c:1202)   <-- no isshared() check
       -> luaH_pset  (ltable.c)
       -> luaH_psetshortstr / psetint
              existing key: setobj(...) stores in place, returns HOK
```

```c
void luaH_set (lua_State *L, Table *t, const TValue *key, TValue *value) {
  int hres = luaH_pset(t, key, value);
  if (hres != HOK)
    luaH_finishset(L, t, key, value, hres);
}
```

`luaH_finishset()` does hold the `isshared()` guard, but it only runs when
`luaH_pset()` returns something other than `HOK`. And `luaH_pset()` is not a
pure lookup: for a key that **already exists** it performs the store itself and
returns `HOK`, so the guard is never reached.

That explains the asymmetry:

| operation | result | why |
|-----------|--------|-----|
| `shared.k = v` | rejected | `luaV_finishset` (`lvm.c`) checks `isshared` |
| `rawset(shared, existing_key, v)` | **accepted, data corrupted** | `luaH_pset` stores in place, returns `HOK` |
| `rawset(shared, new_key, v)` | rejected | `insertkey` fails → `luaH_finishset` → guard fires |

A regression test has to cover **both** rawset cases. Testing only the "new
key" path would report success on a still-broken build.

Note that `luaH_setint()` in the same file *does* carry the check — `luaH_set()`
is the odd one out. (`rawset` with an integer key still gets through, because it
routes via `luaH_set` → `psetint`, not via `luaH_setint`.)

## Fix

```c
 void luaH_set (lua_State *L, Table *t, const TValue *key, TValue *value) {
+  if (l_unlikely(isshared(t)))
+    luaG_runerror(L, "attempt to change a shared table");
   int hres = luaH_pset(t, key, value);
```

## Reproduce

The runner only discovers `test/cases/test_*.lua`, so this lives outside the
test suite and CI never runs it. To trigger it manually:

```sh
make build
cd skynet && ./skynet ../repro/sharetable_rawset/config
```

Observed on the current submodule (Lua 5.5):

```
published: existing=1 [1]=10
plain assign      -> rejected, existing=1
rawset existing   -> ACCEPTED, existing=99 (expected 1)
rawset [1]        -> ACCEPTED, [1]=88 (expected 10)
rawset new key    -> rejected, brandnew=nil (expected nil)
!!! REPRODUCED: rawset bypassed the read-only guard
```

Unlike the GC issue this one is fully deterministic and needs no special
resources — a single `rawset` corrupts data that every other service is reading.
