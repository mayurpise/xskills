<!-- First-party xskills ruleset — NOT part of the upstream mirror. The mirrored
     files are the ones listed in rulesets/UPSTREAM.lock, managed by
     scripts/sync-upstream.sh; this file is authored and maintained in xskills. -->

> Consulted only when no language-specific ruleset matches the file. Favor precision over recall: raise an issue only when you are confident it is a real defect in *this* language's semantics, and stay silent when the surrounding context is unclear.

#### Go
- Unchecked `err`, or `err` shadowed by `:=` inside an inner scope so the outer check reads a stale value
- `defer` inside a loop — cleanup stacks until the function returns, not the iteration
- Goroutines started with no way to stop: no `context`, no `WaitGroup`, no bounded channel; a leaked goroutine holds its captured memory forever
- Writes to a nil map, and appends to a slice aliased by another variable
- A `sync.Mutex` (or a struct containing one) copied by value — the copy locks nothing
- `time.After` in a `select` loop, allocating a timer per iteration

#### Rust
- `unwrap`/`expect` on a path reachable from untrusted input; a panic here is the failure mode, not the error
- `unsafe` blocks with no comment stating the invariant that makes them sound
- Panics crossing an FFI boundary (undefined behavior), and `catch_unwind` used to paper over one
- Blocking calls (`std::fs`, `std::thread::sleep`, a sync mutex held across `.await`) inside async code
- `clone()` in a hot loop where a borrow would do — flag only when the loop is genuinely hot

#### Java / Kotlin
- Nullability at API edges: a method that can return null with no `Optional`/`@Nullable`, or a Kotlin platform type crossing into non-null code
- `equals` changed without `hashCode` (or the reverse) — the pair is one contract
- Resources acquired outside try-with-resources / `use`, so an exception skips `close()`
- Exceptions caught and dropped, or caught as `Exception` where the code handles one specific failure
- Mutable static state, and collections handed out by reference where the caller can mutate internals

#### C / C++
- Ownership and lifetime after the change: a pointer or reference outliving what it points at, double free, use after move
- Unchecked bounds and integer overflow, especially where a size or index derives from input
- Error paths that skip cleanup — the `goto fail` shape, or an early `return` before the free
- `strcpy`/`sprintf`/`gets` family on a buffer whose size is not proven at the call site

#### SQL and migrations
- A new filter, join, or ORDER BY column with no index behind it
- An unbounded backfill or `UPDATE` in one transaction — lock duration grows with the table
- A dropped or renamed column, or a narrowed type, while the previous release still reads it (rollback breaks)
- A migration with no down path, where the project's other migrations have one
- String-concatenated SQL where the driver offers parameters

#### YAML / JSON config, CI, IaC
- Duplicate keys — last one silently wins
- Unquoted `yes`/`no`/`on`/`off` and version scalars (`1.10` → `1.1`) parsed as the wrong type
- Permissions or network exposure widened: a token scoped beyond the job, a security group or bucket opened to the world, a container gaining root or the docker socket
- Secrets committed, or echoed into logs by a step that runs with them in the environment
- An action, image, or module pinned to a mutable tag rather than a digest or version
