(lang dune 3.14)
(name ananke)
(version 0.1.0)
(generate_opam_files true)
(source (github DevomB/Ananke))
(authors "Devom")
(maintainers "Devom")
(license MIT)

(package
 (name ananke)
 (synopsis "Deterministic event-systems laboratory")
 (description
  "A typed deterministic event runtime with replay, snapshot diffing, and invariant verification.")
 (depends
  dune
  base
  sexplib
  ppx_jane
  ppx_inline_test
  ppx_expect))

(package
 (name ananke-cli)
 (synopsis "CLI for Ananke")
 (description "Command-line interface for the Ananke event runtime.")
 (depends ananke cmdliner))
