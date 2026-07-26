(lang dune 3.14)
(name chronicle)
(generate_opam_files true)
(source (github user/chronicle))
(authors "Devom")
(maintainers "Devom")
(license MIT)

(package
 (name chronicle)
 (depends
  dune
  base
  core
  ppx_jane
  ppx_inline_test
  ppx_expect))

(package
 (name chronicle-cli)
 (depends chronicle core cmdliner))
