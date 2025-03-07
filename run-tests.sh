#!/usr/bin/env bash

set -e

source ./build.sh

declare PLATFORM_RESULTS=()
# store how many times we call build_project
declare BUILD_VARIANT_COUNT=0

# Can be set as environment variable
if [ -z "$BUILD_SERVER" ]; then
	BUILD_SERVER=https://build-stage.defold.com
	#BUILD_SERVER=http://localhost:9000
fi

log "**********************************"
log "Using extender server ${BUILD_SERVER}"
if [ ! -z "$EXTENDER_HEADER_NAME" ]; then
	SERVER_VERSION=$(wget --header "${EXTENDER_HEADER_NAME}: ${EXTENDER_HEADER_VALUE}" -q -O - $BUILD_SERVER)
else
	SERVER_VERSION=$(wget -q -O - $BUILD_SERVER)
fi
log "${SERVER_VERSION}"
log "**********************************"


if [ -z "$PLATFORMS" ]; then
	PLATFORMS="armv7-android,arm64-ios,js-web,x86_64-win32,x86_64-linux,x86_64-macos"
fi
log "Using platforms ${PLATFORMS}"

if [ -z "$PROJECT" ]; then
	log "No project specified!"
	exit 1
fi

if [ -z "$CHANNEL" ]; then
	CHANNEL=alpha
fi

if [ -z "$ARCHIVE_PATH" ]; then
	ARCHIVE_PATH=d.defold.com
fi

case ${CHANNEL} in
"alpha"|"beta"|"stable")
	unset SHA1
	log "Using channel ${CHANNEL}"
	;;
*)
	SHA1=${CHANNEL}
	unset CHANNEL
	log "Using sha1 ${SHA1}"
	;;
esac

if [ -z "$HANDLE_ERRORS" ]; then
	HANDLE_ERRORS="true"
fi

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

BUILD_FOLDER=build
if [ ! -d "$BUILD_FOLDER" ]; then
	mkdir -p $BUILD_FOLDER
fi

ERRORTXT=${SCRIPTDIR}/errors.txt

function cleanup() {
	log "Cleaning up"
	cd $SCRIPTDIR
	log "Removing" ./$BUILD_FOLDER
	rm -rf ./$BUILD_FOLDER
	log "Removing jre"
	rm -rf ./jre || true
	log "Removing tar files"
	rm ./*.tar.gz* || true
	log "Removing jar files"
	rm ./*.jar || true
}
trap cleanup 0

download_project() {
	local url=$1
	local name=project
	local zipname=${name}.zip
	log "Downloading ${url}"
	curl -L -o $BUILD_FOLDER/$zipname $url
	unzip -q $BUILD_FOLDER/$zipname -d $BUILD_FOLDER/$name
	rm $BUILD_FOLDER/$zipname
}

check_error() {
	local status=$1
	local name=$2
	local platform=$3
	local variant=$4
	if [ $status -ne 0 ]; then
		touch ${ERRORTXT}
		log "Failed to build '${name}' for '${platform}' variant '${variant}'" >> "${ERRORTXT}"
	fi
}

check_failed_builds() {
	if [ -f ${ERRORTXT} ]; then
		echo "At least one of the builds failed:"
		cat ${ERRORTXT}
		exit 1
	fi
}

# Function to shuffle an array passed as a parameter
shuffle() {
    local i tmp size max rand shuffled_string
    IFS=',' read -ra arr <<< "$1"
    # Get the size of the array
    size=${#arr[*]}
    # Maximum random number
    max=$(( 32768 / size * size ))

    for ((i=size-1; i>0; i--)); do
        # Get a random number within the range
        while (( (rand = RANDOM) >= max )); do :; done
        # Perform a modulo operation to get a number within the array size
        rand=$(( rand % (i+1) ))
        # Swap the elements
        tmp=${arr[i]}
        arr[i]=${arr[rand]}
        arr[rand]=$tmp
    done
    shuffled_string=$(IFS=,; echo "${arr[*]}")
    echo "$shuffled_string"
}

build_project() {
	local platforms_str=$1
	local platforms=(${platforms_str//,/ })
	local url=$2
	local variant=$3

	local projectfile=`find $BUILD_FOLDER/$name -name game.project`
	local projectdir="$(dirname $projectfile)"
	pushd $projectdir

	BUILD_VARIANT_COUNT=$((BUILD_VARIANT_COUNT+1))
	resolve

	local idx=0
	for i in ${platforms[@]}; do
		log "Building $url for ${i}"

		if [ "$HANDLE_ERRORS" == "true" ]; then
			echo "DISABLING ERRORS"
			set +e
		fi
		bob --platform ${i} build --build-server $BUILD_SERVER --use-async-build-server --defoldsdk ${SHA1} --variant=$variant
		bob_exit_code=$?
		check_error $bob_exit_code $url $i $variant
		if [[ $bob_exit_code -eq 0 && "${GITHUB_ACTIONS:-false}" == "true" ]]; then
			PLATFORM_RESULTS[$idx]=$(( ${PLATFORM_RESULTS[$idx]:-0} + 1 ))
		fi
		idx=$((idx+1))

		if [ "$HANDLE_ERRORS" == "true" ]; then
			set -e
		fi
	done

	popd
}

log "Using Java"
which java
java -version

download_bob

shuffled_platform=$(shuffle $PLATFORMS)
splitted_platforms=(${shuffled_platform//,/ })

if [ ${GITHUB_ACTIONS:-false} == "true" ]; then
	arr_len=${#splitted_platforms[@]}
	for (( idx=0; idx<arr_len; idx++ )); do
		PLATFORM_RESULTS+=(0)
	done
fi

echo ${PLATFORM_RESULTS[@]}

download_project $PROJECT
build_project $shuffled_platform $PROJECT debug
build_project $shuffled_platform $PROJECT release
build_project $shuffled_platform $PROJECT headless
rm -rf $BUILD_FOLDER

if [ ${GITHUB_ACTIONS:-false} == "true" ]; then
	success_platform=()
	idx=0

	for platform in ${splitted_platforms[@]}; do
		if [ ${PLATFORM_RESULTS[$idx]} -eq $BUILD_VARIANT_COUNT ]; then
			success_platform+=(${platform})
		fi
		idx=$((idx+1))
	done
	echo $(IFS=,; echo "${success_platform[*]}")
	echo $(IFS=,; echo "${success_platform[*]}") >> ./succeeded_platforms
fi

check_failed_builds
