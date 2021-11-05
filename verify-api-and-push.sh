#!/bin/bash -eu

WHITE=$(tput setaf 7)
RED=$(tput setaf 9)
CLEAR=$(tput sgr0)

cd "$(git rev-parse --show-toplevel)"
BRANCH="$(basename $(dirname $PWD))"

TEMPORARY_FILE=
function report ()
{
	EC="$?"

	if test -f "$TEMPORARY_FILE"; then
		rm -f "$TEMPORARY_FILE"
	fi

	if [[ x$EC == x0 ]]; then
		MESSAGE="success for $1 in $BRANCH"
	else
		MESSAGE="failure for $1 in $BRANCH"
	fi

	say "$MESSAGE" &> /dev/null &
}

trap "report build" EXIT

PUSH=
PR=
NO_UI=
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
		--no-ui)
			NO_UI=1
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

if [[ "1" == "$PR" && "1" == "$NO_UI" ]]; then
	PREVIOUS=$(git log -1 HEAD^ --pretty=%H)
	if ! git log --pretty=%H origin/main | grep "$PREVIOUS" &> /dev/null; then
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
	MESSAGE_COMMAND=
	if test -n "$NO_UI"; then
		TEMPORARY_FILE=$(mktemp)
		git log --format=%B -1 > "$TEMPORARY_FILE"
		MESSAGE_COMMAND="-F $TEMPORARY_FILE"
	fi
	pushpr $LABEL_COMMAND $MESSAGE_COMMAND
elif test -n "$PUSH"; then
	git push
fi
