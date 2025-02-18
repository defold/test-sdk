#!/usr/bin/env bash

set -e

source ./../build.sh

# Can be set as environment variable
if [ -z "$BUILD_SERVER" ]; then
	BUILD_SERVER=https://build-stage.defold.com
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

SERVER_SHA=""
SERVER_VERSION_STR=""
ENGINE_VERSION=""
DEFOLDSDK_SHA=""

BUILD_FOLDER=build
if [ ! -d "$BUILD_FOLDER" ]; then
	mkdir -p $BUILD_FOLDER
fi

ERRORTXT=${SCRIPTDIR}/errors.txt
REPORTS_FOLDER=${SCRIPTDIR}/build_reports
RESULT_FOLDER=${SCRIPTDIR}/time_results
RESULT_FILE=${RESULT_FOLDER}/latest.csv

rm -rf $REPORTS_FOLDER
mkdir -p $REPORTS_FOLDER

BUILD_DATE=$(date "+%Y-%m-%dT%H:%M:%S")

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
	rm -rf $REPORTS_FOLDER || true
	rm -rf $RESULT_FOLDER || true
}
trap cleanup 0

check_error() {
	local status=$1
	local platform=$2
	if [ $status -ne 0 ]; then
		touch ${ERRORTXT}
		log "Failed to build ${platform}" >> "${ERRORTXT}"
	fi
}

check_failed_builds() {
	if [ -f ${ERRORTXT} ]; then
		echo "At least one of the builds failed:"
		cat ${ERRORTXT}
		exit 1
	fi
}

build_project() {
	local platforms=(${1//,/ })

	for i in ${platforms[@]}; do
		log "Building for ${i}"

		if [ "$HANDLE_ERRORS" == "true" ]; then
			echo "DISABLING ERRORS"
			set +e
		fi
		bob --platform ${i} resolve build --build-server $BUILD_SERVER --use-async-build-server --defoldsdk ${SHA1} --variant=debug -v --build-report ${REPORTS_FOLDER}/${i}.json --build-report-html ${REPORTS_FOLDER}/${i}.html
		exit_code=$?
		check_error $exit_code $i
		if [ $exit_code = 0 ]; then
			echo "Add record for ${i}"
			time=$(jq '                                                                                                             
				( .marks[] | select(.shortName == "FinishedBuildRemoteEngine") | .timestamp )
				-
				( .marks[] | select(.shortName == "StartBuildRemoteEngine") | .timestamp )
				' ${REPORTS_FOLDER}/${i}_time.json)
			# date,server,server_sha,server_version,defoldsdk_version,engine_version,engine_channel,platform,build_time
			echo "${BUILD_DATE},${BUILD_SERVER},${SERVER_SHA},${SERVER_VERSION_STR},${DEFOLDSDK_SHA},${ENGINE_VERSION},${CHANNEL},${i},${time}" >> $RESULT_FILE
		fi

		if [ "$HANDLE_ERRORS" == "true" ]; then
			set -e
		fi
	done
}

log "Using Java"
which java
java -version

download_bob

echo "Cleanup previuos results"
mkdir -p $RESULT_FOLDER
touch $RESULT_FILE

# bob.jar version: 1.9.1  sha1: 691478c02875b80e76da65d2f5756394e7a906b1  built: 2024-07-26 13:13:3
ENGINE_VERSION=$(java -jar ${BOB_JAR} --version | awk '{print $3}' | tr '' '\n')
DEFOLDSDK_SHA=$(java -jar ${BOB_JAR} --version | awk '{print $5}' | tr '' '\n')

# Extender<br>959e837<br>2024-08-16 15:22:46
SERVER_SHA=$(echo $SERVER_VERSION | awk -F '<br>' '{print $2}')
build_project $PLATFORMS

echo "Upload results to Bigquery..."
bq load defold_engine_data.extender_build_time $RESULT_FILE

check_failed_builds
