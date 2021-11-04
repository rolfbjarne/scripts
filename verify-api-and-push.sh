#!/bin/bash -eux

cd "$(git rev-parse --show-toplevel)"

function report ()
{
	EC="$?"
	if [[ x$EC == x0 ]]; then
		say "API success $1"
	else
		say "API failure $1"
	fi
}

trap "say 'API verification failed catastrophically'" ERR
trap "report build" EXIT

nice make -j8 all
nice make -j8 install

trap "report xtro" EXIT
make -C tests/xtro-sharpie -j

trap "report monotouch test build" EXIT
make -C tests/monotouch-test/dotnet/macOS build

trap "report monotouch test execution" EXIT
make -C tests/monotouch-test/dotnet/macOS run-bare

