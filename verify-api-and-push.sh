#!/bin/bash -eu

WHITE=$(tput setaf 7)
RED=$(tput setaf 9)
CLEAR=$(tput sgr0)

cd "$(git rev-parse --show-toplevel)"
BRANCH="$(basename $(dirname $PWD))"
function report ()
{
	EC="$?"
	if [[ x$EC == x0 ]]; then
		say "success for $1 in $BRANCH"
	else
		say "failure for $1 in $BRANCH"
	fi
}

trap "report build" EXIT

PUSH=
PR=
LABELS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		--help | -\? | -h)
			echo "$(basename "$0"): --push --pr"
			echo "    <tool description>"
			echo "    Options:"
			echo "        -h --help:         Show this help"
			echo "        -v --verbose:      Enable verbose script"
			echo "        --push:            Execute 'git push' if completed successfully"
			echo "        --pr:              Create a pull request if completed successfully"
			echo "        -l -labels:        Labels to add to the pull request"
			exit 0
			;;
		--verbose | -v)
			set -x
			shift
			;;
		--push)
			PUSH=1
			shift
			;;
		--pr)
			PR=1
			shift
			;;
		--label | -l)
			LABELS+=("$2")
			shift 2
			;;
		--label=)
			LABELS+=("${1#*=}")
			shift
			;;
		*)
			echo "${RED}$(basename "$0"): Unknown option: $1. Pass --help to view the available options.${CLEAR}"
			exit 1
			;;
	esac
done

if test -z "$PUSH$PR"; then
	echo "${RED}Pass either --push or --pr${CLEAR}"
	exit 1
fi

if [ -n "$(git status --porcelain --ignore-submodule)" ]; then
	echo "${RED}Working directory is not clean:${CLEAR}"
	git status --ignore-submodule | sed 's/^/    /'
	exit 1
fi

if test -n "$PR"; then
	PREVIOUS=$(git log -1 HEAD^ --pretty=%H)
	if ! git log --pretty=%H origin/main | grep "$PREVIOUS"; then
		echo "${RED}More than one commit from main!${CLEAR}"
		git log --no-merges head ^origin/main --oneline | sed 's/^/    /'
		exit 1
	fi
fi

nice make -j8 all
nice make -j8 install

trap "report xtro" EXIT
nice make -C tests/xtro-sharpie -j

trap "report monotouch test build" EXIT
nice make -C tests/monotouch-test/dotnet/macOS build

trap "report monotouch test execution" EXIT
nice make -C tests/monotouch-test/dotnet/macOS run-bare

if test -n "$PR"; then
	LABEL_COMMAND=$(printf ",%s" "${LABELS[@]}")
	LABEL_COMMAND=${LABEL_COMMAND:1}
	if test -n "$LABEL_COMMAND"; then
		LABEL_COMMAND="-l $LABEL_COMMAND"
	fi
	pushpr $LABEL_COMMAND
elif test -n "$PUSH"; then
	git push
fi
