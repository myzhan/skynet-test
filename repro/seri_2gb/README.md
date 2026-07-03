# Known issue: cross-service table > 2GB crashes the process

Sending a table whose serialized size exceeds **2GB** across services (e.g.
via `skynet.call`) aborts the whole skynet process.

## Root cause

`skynet/lualib-src/lua-seri.c` tracks the serialization buffer length in a
32-bit signed `int` (`struct write_block.len`, `struct read_block.len`). Once
the packed payload passes `2^31` bytes the counter overflows to a negative
value; `seri()` then calls `skynet_malloc()` with that negative length
sign-extended to a huge `size_t`, and the allocator aborts:

```
xmalloc: Out of memory trying to allocate 18446744072098938907 bytes
```

Same 32-bit truncation also affects the unpack side (`read_block.len`) and the
`(int)sz` cast in `pack_one` (a single string > 2GB is silently corrupted).

## Reproduce (crashes on purpose — NOT part of `make test`)

The runner only discovers `test/cases/test_*.lua`, so this reproduction lives
outside the test suite and CI never runs it. To trigger it manually:

```sh
make build
cd skynet && ./skynet ../repro/seri_2gb/config
```

Expected: the process aborts with the `xmalloc` message above (exit code 134).
Needs ~3GB of free RAM.
