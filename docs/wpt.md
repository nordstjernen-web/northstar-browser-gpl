# Testing Nordstjernen with the web-platform-tests (WPT)

Nordstjernen can run [web-platform-tests](https://github.com/web-platform-tests/wpt)
testharness.js tests headlessly and report per-subtest results. This is
the cross-browser conformance suite shared by Chromium, Gecko, and
WebKit; running slices of it against Nordstjernen is a fast way to find
and track engine gaps.

## Scope

Supported: **testharness.js tests** — plain `.html` tests and the
server-generated `.any.html` / `.window.html` wrappers for `.any.js`
and `.window.js` files.

Not supported: reftests, crashtests, `.worker.js` / service-worker
tests, wdspec tests, manual tests, and print tests. The runner skips
them during enumeration.

## One-time setup

Clone WPT and install its hosts entries (the WPT server expects
`web-platform.test` and friends to resolve to 127.0.0.1):

```sh
git clone --depth 1 https://github.com/web-platform-tests/wpt.git ~/wpt
cd ~/wpt && ./wpt make-hosts-file | sudo tee -a /etc/hosts
```

WPT's server only needs Python 3; everything else is vendored in its
checkout.

## Running tests

Build the browser first (`scripts/dev.sh build`), then:

```sh
# A directory of tests
scripts/wpt-run.sh --wpt-root=~/wpt dom/events

# Individual tests (paths relative to the WPT checkout)
scripts/wpt-run.sh --wpt-root=~/wpt url/url-tojson.any.js dom/nodes/Element-tagName.html

# Just enumerate, don't run
scripts/wpt-run.sh --wpt-root=~/wpt --list dom/events
```

The runner starts `./wpt serve` itself (and stops it on exit) unless a
server is already reachable; pass `--no-serve` to require an external
server. Other options: `--base=URL` (default
`http://web-platform.test:8000`), `--timeout-ms=N` per test (default
15000), and `--results=FILE` to append one JSON line per test:

```json
{"test":"/url/url-tojson.any.html","exit":0,"result":{"harness":"OK","message":null,"subtests":[...]}}
```

The runner exits 0 only when every test file ran without failures.

## Running a single test by hand

The runner is a thin loop around the browser's headless WPT mode,
which is also usable directly against any URL serving a testharness.js
test:

```sh
./builddir/src/gtk/nordstjernen --wpt http://web-platform.test:8000/dom/events/CustomEvent.html
./builddir/src/gtk/nordstjernen --wpt --wpt-timeout-ms=30000 http://localhost:8000/some/test.html
```

Output on stdout, one line per subtest:

```
WPT HARNESS OK
WPT PASS sync pass
WPT FAIL sync fail | assert_equals: math expected 3 but got 2
WPT SUMMARY total=2 pass=1 fail=1 timeout=0 notrun=0 precondition_failed=0
WPT JSON {"harness":"OK","message":null,"subtests":[...]}
```

Exit codes: `0` — harness OK and every subtest passed; `1` — at least
one subtest failed (or the harness errored); `2` — the page never
produced results before the timeout (testharness.js missing, or tests
hung).

## How it works

`--wpt` makes the headless driver inject a hook script
(`data/js/wpt-hook.js`, embedded into the binary at build time) into
the fresh JS context before any document script runs. The hook places
an accessor trap on `globalThis.add_completion_callback`; when
testharness.js defines that function the trap registers a completion
callback with the harness — via a microtask, since testharness.js
creates its internal `Tests` object after exposing the API — and then
restores the plain function. On completion the callback serializes the
harness status and every subtest result into globals that the driver
polls from C (`src/headless.c`), prints, and turns into the exit code.
Because registration happens before the test script executes, even
tests that complete synchronously during parsing are captured. No
modification of the WPT checkout (e.g. replacing
`testharnessreport.js`) is needed.
