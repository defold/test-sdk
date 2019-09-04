#!/usr/bin/env bash

set -e

source ./build.sh

# Can be set as environment variable
if [ -z "$BUILD_SERVER" ]; then
	BUILD_SERVER=https://build-stage.defold.com
	#BUILD_SERVER=http://localhost:9000
fi
log "Using extender server ${BUILD_SERVER}"

if [ -z "$PLATFORMS" ]; then
	PLATFORMS="js-web,x86-win32,x86_64-win32,x86_64-linux,x86_64-darwin,armv7-darwin,armv7-android"
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
	rm -rf ./jre
	log "Removing tar files"
	rm ./*.tar.gz*
	log "Removing jar files"
	rm ./*.jar
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
	download_project $url

	local projectfile=`find $BUILD_FOLDER/$name -name game.project`
	local projectdir="$(dirname $projectfile)"
	pushd $projectdir

	resolve foo@bar.com 123456

	for i in ${platforms[@]}; do
		log "Building $url for ${i}"

		set +e
		bob --platform ${i} build --build-server $BUILD_SERVER --defoldsdk ${SHA1}
		check_error $? $url $i
		set -e
	done

	popd
	rm -rf $projectdir
}

function download_java() {
    local package=jre-8u102-linux-x64.tar.gz
    local host=`uname`
    if [ "$host" == "Darwin" ]; then
    	package=jre-8u102-macosx-x64.tar.gz
    fi
	mkdir jre
	wget -q https://s3-eu-west-1.amazonaws.com/defold-packages/$package
	tar -C jre -xzf $package --strip-components=1
	PWD=`pwd`
	export JAVA_HOME=${PWD}/jre
    if [ "$host" == "Darwin" ]; then
		export PATH=${PWD}/jre/Contents/Home/bin:${PATH}
	else
		export PATH=${PWD}/jre/bin:${PATH}
	fi
}

download_java

log "Using Java"
which java
java -version

download_bob

PROJECTS=(${PROJECTS//,/ })
for project in ${PROJECTS[@]}; do
	build_project $PLATFORMS $project
done

cd ${SCRIPTDIR}
check_failed_builds
