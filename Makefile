.PHONY: build test fmt clean install doctor demo-elevator demo-ledger demo-matching-engine benchmark report-elevator

build:
	dune build

test:
	dune runtest

fmt:
	dune build @fmt --auto-promote

clean:
	dune clean

install:
	dune build @install

doctor:
	dune exec ananke -- doctor

demo-elevator:
	dune exec ananke -- run --domain elevator examples/elevator/scenarios/up_down.sexp

demo-ledger:
	dune exec ananke -- run --domain ledger examples/ledger/scenarios/deposit_withdraw.sexp

demo-matching-engine:
	dune exec ananke -- run --domain matching_engine examples/matching_engine/scenarios/basic.sexp

benchmark:
	dune exec ananke -- benchmark --iterations 1000 --domain elevator

report-elevator:
	dune exec ananke -- report examples/elevator/scenarios/up_down.trace.sexp
