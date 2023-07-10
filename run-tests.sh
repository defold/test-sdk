#!/usr/bin/env bash

set -e

source ./build.sh

# Can be set as environment variable
if [ -z "$BUILD_SERVER" ]; then
	BUILD_SERVER=https://build-stage.defold.com
	#BUILD_SERVER=http://localhost:9000
fi

log "**********************************"
log "Using extender server ${BUILD_SERVER}"
SERVER_VERSION=$(wget -q -O - $BUILD_SERVER)
log "${SERVER_VERSION}"
log "**********************************"


if [ -z "$PLATFORMS" ]; then
	PLATFORMS="armv7-android,arm64-ios,js-web,x86_64-win32,x86_64-linux,x86_64-macos"
fi
log "Using platforms ${PLATFORMS}"

if [ -z "$PROJECTS" ]; then
	log "No projects specified!"
	exit 1
fi
# Replace new lines with comma
PROJECTS=$(echo $PROJECTS | tr '\n' ',' | tr ' ' ',')

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

ERRORTXT=${BUILD_FOLDER}/errors.txt

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
	if [ $status -ne 0 ]; then
		pushd $SCRIPTDIR
		touch ./${ERRORTXT}
		log "Failed to build '${name}'' for ${platform}" >> "./${ERRORTXT}"
		popd
	fi
}

check_failed_builds() {
	if [ -f ./${ERRORTXT} ]; then
		echo "At least one of the builds failed:"
		cat ./${ERRORTXT}
		exit 1
	fi
}

build_project() {
	local platforms=(${1//,/ })
	local url=$2
	local variant=$3

	local projectfile=`find $BUILD_FOLDER/$name -name game.project`
	local projectdir="$(dirname $projectfile)"
	pushd $projectdir

	resolve foo@bar.com 123456

	for i in ${platforms[@]}; do
		log "Building $url for ${i}"

		if [ "$HANDLE_ERRORS" == "true" ]; then
			echo "DISABLING ERRORS"
			set +e
		fi
		bob --platform ${i} build --build-server $BUILD_SERVER --use-async-build-server --defoldsdk ${SHA1} --variant=$variant
		check_error $? $url $i

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

PROJECTS=(${PROJECTS//,/ })
for project in ${PROJECTS[@]}; do
	download_project $project
	build_project $PLATFORMS $project debug
	build_project $PLATFORMS $project release
	build_project $PLATFORMS $project headless
done

cd ${SCRIPTDIR}
check_failed_builds
