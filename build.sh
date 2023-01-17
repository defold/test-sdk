#!/usr/bin/env bash

# Bulk of the setup is taken from https://github.com/britzl/defold-builder/blob/master/build.sh

usage()
{
	echo "
This tool downloads the latest bob.jar and builds a set of projects for all platforms

usage: build.sh [options] [command ...]
options:
	-h | --help                       Show this help
	--sha1                 	          (string) SHA1 of engine to use
	--channel                         (alpha|beta|stable) Get SHA1 of engine from latest
	--archive-path                    (string) Bucket to download from. Default is d.defold.com
	-p | --platform                   (string) Platform to build for
	-v | --verbose                    Show verbose output from bob.jar
	--log                             Show verbose output this script
commands:
	build
"
}

log() {
	#if [ ! -z ${LOG} ]; then
		echo "$@"
	#fi
}

while [ "$1" != "" ]; do
	PARAM=`echo $1 | awk -F= '{print $1}'`
	VALUE=`echo $1 | awk -F= '{print $2}'`
	if [[ ${PARAM} != -* ]]; then
		break
	fi
	case ${PARAM} in
		-h | --help)
			usage
			exit
			;;
		--sha1)
			SHA1="${VALUE}"
			;;
		--channel)
			CHANNEL="${VALUE}"
			;;
		--archive-path)
			ARCHIVE_PATH="${VALUE}"
			;;
		-p | --platform)
			PLATFORM="${VALUE}"
			;;
		-v | --verbose)
			VERBOSE="${PARAM}"
			;;

		*)
			echo "ERROR: unknown parameter \"$PARAM\""
			usage
			exit 1
			;;
	esac
	shift
done

download_bob() {
	log "Downloading BOB"

	if [ ! -z ${CHANNEL} ]; then
		SHA1=$(curl -H 'Cache-Control: no-cache' -s http://${ARCHIVE_PATH}/${CHANNEL}/info.json | sed 's/.*sha1": "\(.*\)".*/\1/')
		log "Using SHA1 of latest release on channel ${CHANNEL} (SHA1: '${SHA1}')"
	elif [ -z ${SHA1} ]; then
		SHA1=$(curl -H 'Cache-Control: no-cache' -s http://${ARCHIVE_PATH}/stable/info.json | sed 's/.*sha1": "\(.*\)".*/\1/')
		log "Using SHA1 of latest stable release (SHA1: '${SHA1}')"
	else
		log "Using predefined SHA1 (SHA1: '${SHA1}')"
	fi

	local pwd=`pwd`
	BOB_JAR=$pwd/bob_${SHA1}.jar
	BOB_URL="http://${ARCHIVE_PATH}/archive/${SHA1}/bob/bob.jar"
	if [ ! -f ${BOB_JAR} ]; then
		log "Downloading ${BOB_URL}"
		curl -L -o ${BOB_JAR} ${BOB_URL}
	fi
}

bob() {
	log "bob $@"
	#java -Djava.ext.dirs=${JAVA_HOME}/jre/lib/ext -jar ${BOB_JAR} ${VERBOSE} "$@"
	java -jar ${BOB_JAR} ${VERBOSE} "$@"
	return $?
}

clean() {
	bob clean
}

resolve() {
	if [ -z "${1}" ]; then usage; exit 1; fi
	if [ -z "${2}" ]; then usage; exit 1; fi
	log "Resolving dependencies"
	bob --email "${1}" --auth "${2}" resolve
}

build() {
	if [ -z "${PLATFORM}" ]; then usage; exit 1; fi
	log "Building ${PLATFORM}"
	bob --platform ${PLATFORM} ${ARCHIVE} build
}


