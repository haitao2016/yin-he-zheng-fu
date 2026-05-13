# Debugging

Systematic debugging methodology applicable across all languages and frameworks.

## The Debugging Mindset

> "Debugging is twice as hard as writing code. If you write code as cleverly as possible, you are by definition not smart enough to debug it." — Brian Kernighan

**Three cardinal rules**:
1. **Never guess** — Form hypotheses and test them systematically
2. **One change at a time** — Isolate variables to identify causation
3. **Trust the error message** — Read it fully before theorizing

## Debugging Workflow (6-Step Method)

```
1. REPRODUCE — Establish consistent reproduction steps
     ├─ Document exact inputs, environment, and timing
     ├─ Simplify: can you reproduce in a test?
     └─ If intermittent: add logging to capture next occurrence

2. ISOLATE — Narrow to smallest failing case
     ├─ Binary search: comment out half the code
     ├─ git bisect: find the breaking commit
     └─ Minimal reproduction: strip away unrelated code

3. HYPOTHESIZE — Form testable theories
     ├─ List 3-5 possible causes
     ├─ Rank by likelihood
     └─ Design a test for each (what would confirm/refute?)

4. TEST — Verify/disprove each hypothesis (one at a time\!)
     ├─ Add targeted logging or breakpoints
     ├─ Check assumptions (print intermediate values)
     └─ Eliminate impossible causes first

5. FIX — Implement minimal correct fix
     ├─ Fix the root cause, not just symptoms
     ├─ Write regression test BEFORE fixing
     └─ Verify the test fails, apply fix, verify it passes

6. PREVENT — Add regression test + safeguard
     ├─ Add monitoring/alerting for this failure mode
     ├─ Update documentation if behavior was unclear
     └─ Check for similar patterns elsewhere
```

## Debugging Tools by Language

| Language | Debugger | REPL / Interactive | Profiler |
|----------|----------|--------------------|----------|
| Python | pdb / ipdb | `python -i script.py` | cProfile, py-spy |
| JavaScript | Node Inspector | `node --inspect-brk` | Chrome DevTools |
| TypeScript | VS Code debugger | ts-node | Chrome DevTools |
| Go | Delve | — | pprof |
| Rust | LLDB/GDB | — | perf, flamegraph |
| Java | JDB / IntelliJ | jshell | VisualVM, async-profiler |
| C/C++ | GDB/LLDB | — | perf, Valgrind |

### Quick Debugging Commands

```bash
# Python — drop into debugger at specific point
import pdb; pdb.set_trace()           # Python 3.6-
breakpoint()                           # Python 3.7+

# Node.js — debug with Chrome DevTools
node --inspect-brk app.js             # pause on first line
node --inspect app.js                 # attach without pausing

# Go — Delve interactive debugger
dlv debug ./cmd/server                # debug main package
dlv test ./pkg/auth                   # debug tests
dlv attach <pid>                      # attach to running process

# Rust — LLDB
rust-lldb target/debug/app
(lldb) breakpoint set -n main
(lldb) run

# Git — find the breaking commit
git bisect start
git bisect bad HEAD
git bisect good v1.2.0
# test each checkout, then: git bisect good/bad
git bisect reset
```

## Common Bug Patterns & Quick Fixes

| # | Pattern | Symptoms | Root Cause | Quick Fix |
|---|---------|----------|------------|-----------|
| 1 | **Off-by-one** | Array out of bounds, fence post, missing last item | `<` vs `<=`, 0-based vs 1-based | Check loop bounds: `for i in range(len(arr))` |
| 2 | **Null/undefined** | TypeError, NullPointerException, segfault | Uninitialized variable, missing return | Optional chaining `?.`, null checks, `Option` type |
| 3 | **Race condition** | Intermittent failures, data corruption | Concurrent access without synchronization | Mutex, atomic operations, channels |
| 4 | **Memory leak** | Growing memory, OOM, slowdown over time | Missing cleanup, dangling references, event listeners | Profile heap, fix `removeEventListener`, weak refs |
| 5 | **Stale closure** | Old values in callbacks, React stale state | Closure captures variable at creation time | Use refs, dependency arrays, fresh closures |
| 6 | **N+1 query** | Slow page load, high query count | Loop querying inside a loop | Eager loading, `DataLoader`, batch queries, JOINs |
| 7 | **Deadlock** | App hangs, no progress, thread pool exhausted | Circular lock acquisition | Lock ordering, timeout, detect cycles |
| 8 | **Type coercion** | `"1" + 1 = "11"`, `[] == false` | Implicit type conversion | Strict equality `===`, explicit parsing |
| 9 | **Encoding** | Garbled text, mojibake, emoji broken | Mismatched encoding (UTF-8 vs Latin-1) | Ensure UTF-8 everywhere, check BOM |
| 10 | **Time zone** | Wrong dates, off-by-one-day, DST bugs | Mixing local time and UTC | Store UTC, convert at display, use libraries |

## Error Message Decoder

Common error messages and what they actually mean:

### JavaScript / TypeScript
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `Cannot read properties of undefined` | Accessing property of missing object | Check the chain: which part is undefined? |
| `Maximum call stack size exceeded` | Infinite recursion | Add base case, check recursive call arguments |
| `ECONNREFUSED` | Server not running or wrong port | Verify server is up, check host:port |
| `CORS error` | Cross-origin request blocked | Configure CORS headers on server |

### Python
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `AttributeError: NoneType has no attribute` | Function returned None unexpectedly | Check return value before accessing |
| `ModuleNotFoundError` | Package not installed or wrong env | `pip install`, check virtualenv |
| `RecursionError` | Infinite recursion | Add base case, increase limit if justified |
| `KeyError` | Dict key doesn't exist | Use `.get()` with default, or check `in` |

### Go
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `nil pointer dereference` | Accessing method/field on nil pointer | Check for nil before use |
| `deadlock - all goroutines asleep` | Channel or mutex deadlock | Review goroutine lifecycle, use select with timeout |
| `index out of range` | Slice access beyond length | Bounds check before access |

### Java
| Error | Likely Cause | Fix |
|-------|-------------|-----|
| `NullPointerException` | Calling method on null reference | Null check, Optional, @NonNull |
| `ConcurrentModificationException` | Modifying collection during iteration | Use Iterator.remove() or CopyOnWriteArrayList |
| `ClassCastException` | Invalid type cast | Use instanceof check first |

## Systematic Log Analysis

```bash
# Find errors in last 100 lines
tail -100 app.log | grep -i "error\|exception\|fatal"

# Count error frequency by type
grep -o "ERROR: [A-Za-z]*" app.log | sort | uniq -c | sort -rn

# Follow logs in real-time with filtering
tail -f app.log | grep --line-buffered "ERROR\|WARN"

# Find requests slower than 1 second
grep "duration_ms" app.log | awk -F'"duration_ms":' '{if($2 > 1000) print}' 

# Correlate by request ID
grep "req-12345" app.log | sort -t'"' -k2
```

## Rules

### Always
- Reproduce the issue first (no reproduction = no fix)
- Gather complete error messages and stack traces
- Test one hypothesis at a time
- Document findings for future reference
- Add regression tests after fixing
- Remove all debug code before committing
- Check logs from multiple services (distributed debugging)
- Use structured logging (JSON) for machine parsing

### Never
- Guess without testing
- Make multiple changes at once
- Skip reproduction steps
- Assume you know the cause
- Debug in production without safeguards
- Leave console.log/print/debugger statements in code
- Ignore warnings (they often become errors later)
- Fix symptoms instead of root causes
