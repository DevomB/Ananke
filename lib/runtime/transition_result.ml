open Base

type 'state t =
  { state : 'state
  ; emitted : Sexp.t list
  ; trace : Trace.t
  ; metrics : Metrics.t
  ; violations : Violation.t list
  }
