(lang dune 3.14)
(name ananke)
(generate_opam_files true)
(source (github user/ananke))
(authors "Devom")
(maintainers "Devom")
(license MIT)

(package
 (name ananke)
 (depends
  dune
  base
  core
  ppx_jane
  ppx_inline_test
  ppx_expect))

(package
 (name ananke-cli)
 (depends ananke core cmdliner))
