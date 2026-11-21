# Bindlib-compatible implementation: provenance and verification

This document records how `deps/bindlib` was produced and how its behaviour was
verified. It is an engineering record, not a legal opinion; see the project's
`NOTICE` and `THIRD_PARTY_LICENSES.md` for distribution terms.

## Why this module exists

Upstream Catala links [Bindlib](https://github.com/rlepigre/ocaml-bindlib),
which is licensed LGPL-3.0-only **without** an OCaml linking exception. OCaml
native code is statically linked, so distributing a binary that links Bindlib
triggers the relinking obligations of LGPLv3 §4. This module provides an
independent implementation of the Bindlib 6.0.0 public API so that Catala can
be distributed without that dependency.

## What was implemented

The public interface and the documented, observable behaviour of Bindlib 6.0.0
were used as the specification:

- variable identity, identifier allocation and hashing;
- box evaluation (eager `Box` values, deferred `Env` closures, shared
  environments, `minimize`, free-variable tracking);
- single and multi binders, substitution, arity errors and alpha-equivalence;
- `raw_binder` / `raw_mbinder` round-trips;
- the default naming policy and the `Ctxt`/`Renaming` functor;
- `Lift` / `Lift2` and the container combinators.

The implementation is original code: no source lines or comments were copied.

## How behaviour was verified

1. **Differential testing.** A harness (kept outside this repository) executes
   a fixed set of scenarios and prints canonical text: variable names, uids,
   hashes, ordering, closedness, occurrence flags, binder ranks, substitution
   results, laziness and `mkfree` call counts, naming decisions, error
   messages, and `raw_binder` round-trips. The same program is compiled twice,
   once against the reference library and once against this module, and the
   outputs are compared byte for byte (timing lines excluded). All non-timing
   lines are identical.

2. **Catala's own suite.** Re-run on 2026-11-21 with the Chinese lexer
   commits (`catala_zh`) present: `make test` passes **722/722** interpreted
   tests plus 18 OCaml unit tests. This total includes the six
   `tests/zh/good/dialect.catala_zh` CLI cases, which exercise `Typecheck`,
   `test-scope` and the OCaml, C, Python and Java backends (6/6). The four CI
   `--test-flags` variants (`-O`, `--lcalc`,
   `--lcalc,--closure-conversion,-O`, `--whole-program`) each pass **481/481**
   over `tests/`, and the zh scope test passes 1/1 under each variant. Those
   tests compare pretty-printed ASTs, generated code and error messages, so
   they are sensitive to naming and ordering.

3. **Performance.** Micro-benchmarks (100k bind/unbind cycles and 1000
   `box_list` evaluations) are within run-to-run noise of the reference
   implementation.

## Environment evidence (2026-11-21)

- `catala.opam.locked` was regenerated with `opam lock ./catala.opam` on the
  switch actually used for the build: OCaml 4.14.2, dune 3.24.2, sedlex 3.8.1,
  menhir 20250912. The previous lock pinned OCaml 5.3.0 / dune 3.20.2 /
  sedlex 3.7 and did not describe this environment.
- The license bundle was generated with
  `python3 build_system/third_party_licenses.py --bundle _build/third_party-2026-11-21`:
  80 license texts (1.2 MiB), `THIRD_PARTY_LICENSES.md` and `sbom.cdx.json`
  regenerated from the installed dependency set.

## Known intentional difference

`unmbind2_in` is implemented with the correct semantics for both binders. The
reference implementation reads the occurrence flags of its first argument
twice; the behaviour differs only when the two binders describe different
occurrence patterns. Catala does not use `unmbind2_in`.

## Reproducing the differential test

The harness is not part of the build. To run it, create two small dune
projects: one depending on the external `bindlib` package, one on this
directory, both compiling the same `main.ml`, then diff their outputs
(ignoring the timing lines). The harness source and the recorded outputs of
the comparison are archived with the project's legal records.
