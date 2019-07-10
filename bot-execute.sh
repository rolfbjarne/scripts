#!/bin/bash -eu

INTERNAL_BOTS="   xam-macios-mavericks-1 xam-macios-yosemite-1 xam-macios-capitan-1 xam-macios-sierra-1 xam-macios-hsierra-1 xam-jenkins-macios-1 xam-jenkins-macios-2 xam-macios-mojave-1 xam-macios-mojave-2 xam-macios-mojave-3 xam-macios-mojave-4  xam-macios-mojave-5 xam-macios-mojave-6 xam-macios-catalina-1"
INTERNAL_OS_BOTS="xam-macios-mavericks-1 xam-macios-yosemite-1 xam-macios-capitan-1 xam-macios-sierra-1 xam-macios-hsierra-1 xam-macios-mojave-1 xam-macios-catalina-1"
INTERNAL_DEVICE_BOTS="xam-macios-devices-1 xam-macios-devices-2 xam-macios-devices-3"
PUBLIC_BOTS="xam-mac-mini-26 xam-mac-mini-27 xam-mac-mini-28"

ALL_BOTS=$(echo -e "${PUBLIC_BOTS// /\\n}\\n${INTERNAL_BOTS// /\\n}\\n${INTERNAL_DEVICE_BOTS// /\\n}" | sort -u | grep -v "^$")
ALL_BOTS=${ALL_BOTS//[$'\n']/ }

# I like colors
WHITE=$(tput setaf 7)
BLUE=$(tput setaf 6)
RED=$(tput setaf 9)
CLEAR=$(tput sgr0)

ACTION=
PRE_COMMAND=
COMMAND=
BOTS=
XM_TEST=
COPY_APP=
COPY_FILE=
TIMEOUT=60

function add_bots ()
{
	IFS=', ' read -r -a split <<< "$1"
	for i in ${split[*]}; do
		case "$i" in
			internal)
				BOTS="$BOTS $INTERNAL_BOTS"
				;;
			internal-os)
				BOTS="$BOTS $INTERNAL_OS_BOTS"
				;;
			internal-device)
				BOTS="$BOTS $INTERNAL_DEVICE_BOTS"
				;;
			public)
				BOTS="$BOTS $PUBLIC_BOTS"
				;;
			all)
				BOTS="$BOTS $INTERNAL_BOTS $PUBLIC_BOTS"
				;;
			*)
				BOTS="$BOTS $i"
				;;
		esac
	done
	# deduplicate
	BOTS="$(echo -e "${BOTS// /\\n}" | sort -u | grep -v "^$")"
	BOTS=${BOTS//[$'\n']/ }
}

while [ -n "${1:-}" ]; do
	case $1 in
		--bot | --bots)
			add_bots "$2"
			shift 2
			;;
		--bot=*)
			add_bots "${1:6}"
			shift
			;;
		--bots=*)
			add_bots "${1:7}"
			shift
			;;
		--pre-command=*)
			PRE_COMMAND="${1#*=}"
			shift
			;;
		--pre-command)
			PRE_COMMAND="$2"
			shift 2
			;;
		--command)
			ACTION=execute
			COMMAND="$2"
			shift 2
			;;
		--command=*)
			ACTION=execute
			COMMAND="${1#*=}"
			shift
			;;
		--run-test=*)
			ACTION=runtest
			XM_TEST="${1#*=}"
			shift
			;;
		--run-test)
			XM_TEST="$2"
			shift 2
			;;
		--copy-file=*)
			ACTION=copyfile
			COPY_FILE="${1#*=}"
			shift
			;;
		--copy-file)
			ACTION=copyfile
			COPY_FILE="$2"
			shift 2
			;;
		--copy-app=*)
			ACTION=copyapp
			COPY_APP="${1#*=}"
			shift
			;;
		--copy-app)
			ACTION=copyapp
			COPY_APP="$2"
			shift 2
			;;
		--run-app)
			ACTION=runapp
			COPY_APP="$2"
			shift 2
			;;
		--run-app=*)
			ACTION=runapp
			COPY_APP="${1#*=}"
			shift
			;;
		--timeout=*)
			 TIMEOUT="${1#*=}"
			 shift
			 ;;
		--timeout)
			TIMEOUT="$2"
			shift 2
			;;
		--list-bots)
			echo "Current list of bots:"
			echo -e "${ALL_BOTS// /\\n}" | sed 's/^/    /'
			exit 0
			;;
		--help | -h | -?)
			echo "Opening help in browser..."
			open "https://github.com/rolfbjarne/scripts/tree/master/bot-execute.md"
			echo "Current list of bots: "
			echo -e "${ALL_BOTS// /\\n}" | sed 's/^/    /'
			exit 0
			;;
		*)
			echo "Unknown argument: $1"
			exit 1
			;;
	esac
done

if test -z "$BOTS"; then
	echo "${RED}No bots selected. Pass --bot=<bot> one or more times to select which bots to work with.${CLEAR}"
	exit 1
elif test -z "$ACTION"; then
	echo "${RED}Nothing to do.${CLEAR}"
	exit 1
fi

BOTDIR=$USER
BOTCOUNT=$(wc -w <<< "$BOTS")

function copyapp ()
{
	if test -z "$COPY_APP"; then
		exit
	fi

	echo "Copying '$WHITE$(basename "$COPY_APP")$CLEAR' to $BLUE$BOTS$CLEAR in parallel..."

	for bot in $BOTS; do
		LOGFILE=/tmp/$bot-filetransfer.log
		if (( BOTCOUNT == 1 )); then
			LOGFILE=/dev/stdout
		fi
		echo "Log file for copy on $BLUE$bot$CLEAR: $LOGFILE"
		# shellcheck disable=SC2029
		rsync -avz -e ssh "$COPY_APP" "$bot:~/$BOTDIR/" > "$LOGFILE" 2>&1 &
	done

	wait

	if (( BOTCOUNT != 1 )); then
		for bot in $BOTS; do
			echo "Log file for app copy on $BLUE$bot$CLEAR:"
			sed 's/^/    /' "/tmp/$bot-filetransfer.log"
		done
	fi
}

function copyfile ()
{
	if test -z "$COPY_FILE"; then
		exit
	fi
	echo "Copying '$WHITE$COPY_FILE$CLEAR' to '~/$BOTDIR/$(basename "$COPY_FILE")' in $BLUE$BOTS$CLEAR in parallel..."

	for bot in $BOTS; do
		echo "Log file for copy on $BLUE$bot$CLEAR: /tmp/$bot-filetransfer.log"
		# shellcheck disable=SC2029
		ssh "$bot" 'mkdir -p $HOME/'"$BOTDIR" && scp "$COPY_FILE" "$bot:~/$BOTDIR/" > "/tmp/$bot-filetransfer.log" 2>&1 &
	done
	wait
	for bot in $BOTS; do
		echo "Log file for app copy on $BLUE$bot$CLEAR:"
		sed 's/^/    /' "/tmp/$bot-filetransfer.log"
	done
}

function execute ()
{
	if test -n "$PRE_COMMAND"; then
		COMMAND="$PRE_COMMAND;$COMMAND"
	fi

	echo "Executing '$WHITE$COMMAND$CLEAR' on $BLUE$BOTS$CLEAR in parallel..."

	for bot in $BOTS; do
		LOGFILE=/tmp/$bot.log
		if (( BOTCOUNT == 1 )); then
			LOGFILE=/dev/stdout
		fi
		echo "Log file for execution on $BLUE$bot$CLEAR: $LOGFILE"


		# Check for timeout, and kill if necessary
		(
			BEFORE=$(date +%s)
			ssh -t -t -o StrictHostKeyChecking=no "$bot" "$COMMAND" &> "$LOGFILE" &
			SSH_PID=$!

			(
				sleep 10
				while kill -0 "$SSH_PID" &> /dev/null; do
					NOW=$(date +%s)
					DIFF=$((NOW - BEFORE))
					if (( DIFF >= TIMEOUT )); then
						echo "Execution on $BLUE$bot$CLEAR timed out after $TIMEOUT seconds."
						echo "Execution on $bot timed out after $TIMEOUT seconds." >> "$LOGFILE"
						kill -9 "$SSH_PID"
						break
					else
						echo "$BLUE$bot$CLEAR is still executing after $((DIFF))s"
					fi
					sleep 10
				done
			)&

			SSH_STATUS=0
			wait "$SSH_PID" || SSH_STATUS=$?
			AFTER=$(date +%s)
			echo "Completed execution on $BLUE$bot$CLEAR in $((AFTER - BEFORE))s with exit code $SSH_STATUS."
			echo "Completed execution on $bot in $((AFTER - BEFORE))s with exit code $SSH_STATUS." >> "$LOGFILE"
		)&
	done

	wait

	if (( BOTCOUNT != 1 )); then
		for bot in $BOTS; do
			echo "Log file for execution on $BLUE$bot$CLEAR:"
			sed 's/^/    /' "/tmp/$bot.log"
		done

		for bot in $BOTS; do
			tail -1 -q "/tmp/$bot.log"
		done
	fi
}

function runtest ()
{
	APP_EXECUTABLE=
	case "$XM_TEST" in
		xammac_tests | xammac | xammac-tests)
			BUILD_TARGET=build-mac-modern-xammac_tests
			COPY_APP="$(git rev-parse --show-toplevel)/tests/xammac_tests/bin/x86/Debug/xammac_tests.app"
			APP_EXECUTABLE=xammac_tests.app/Contents/MacOS/xammac_tests
			TIMEOUT=300
			;;
		apitest)
			BUILD_TARGET=build-mac-modern-apitest
			COPY_APP="$(git rev-parse --show-toplevel)/tests/apitest/bin/x86/Debug/apitest.app"
			APP_EXECUTABLE=apitest.app/Contents/MacOS/apitest
			TIMEOUT=60
			;;
		introspection)
			BUILD_TARGET=build-mac-modern-introspection
			COPY_APP="$(git rev-parse --show-toplevel)/tests/introspection/Mac/bin/x86/Debug/introspection.app"
			APP_EXECUTABLE=introspection.app/Contents/MacOS/introspection
			TIMEOUT=120
			;;
		*)
			echo "Unknown Xamarin.Mac test: $XM_TEST"
			exit 1
			;;
	esac

	echo "Building $BUILD_TARGET..."
	make -C "$(git rev-parse --show-toplevel)/tests" "$BUILD_TARGET"

	# Copy to bot(s)
	copyapp

	if test -z "$COMMAND"; then
		COMMAND="export MONO_DEBUG=no-gdb-backtrace; export DISABLE_SYSTEM_PERMISSION_TESTS=1; ~/$BOTDIR/$APP_EXECUTABLE"
	fi
	execute
}

function runapp ()
{
	copyapp

	APPNAME=$(basename -s .app "$COPY_APP")
	#shellcheck disable=SC2088
	COMMAND="~/$BOTDIR/$APPNAME.app/Contents/MacOS/$APPNAME"
	execute
}

case $ACTION in
	runtest)
		runtest
		;;
	copyapp)
		copyapp
		;;
	copyfile)
		copyfile
		;;
	runapp)
		runapp
		;;
	execute)
		execute
		;;
	*)
		echo "${RED} OPS unknown action $ACTION. Implement me!${CLEAR}"
		exit 1
		;;
esac

echo "Completed execution"