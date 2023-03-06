#!/usr/bin/env python3

import os, sys, subprocess
import traceback

PROJECTS=[
"https://github.com/defold/extension-spine/archive/master.zip",
"https://github.com/defold/extension-rive/archive/master.zip",
"https://github.com/defold/extension-adinfo/archive/master.zip",
"https://github.com/defold/extension-admob/archive/master.zip",
# "https://github.com/defold/extension-camera/archive/master.zip",
"https://github.com/defold/extension-facebook/archive/master.zip",
"https://github.com/defold/extension-fbinstant/archive/master.zip",
"https://github.com/defold/extension-firebase/archive/master.zip",
"https://github.com/defold/extension-firebase-analytics/archive/master.zip",
"https://github.com/defold/extension-firebase-remoteconfig/archive/master.zip",
"https://github.com/defold/extension-googleplayinstant/archive/master.zip",
"https://github.com/defold/extension-gpgs/archive/master.zip",
"https://github.com/defold/extension-html5/archive/master.zip",
"https://github.com/defold/extension-iac/archive/master.zip",
"https://github.com/defold/extension-iap/archive/master.zip",
"https://github.com/defold/extension-kaiads/archive/main.zip",
"https://github.com/defold/extension-kaios/archive/main.zip",
"https://github.com/defold/extension-crypt/archive/master.zip",
"https://github.com/defold/extension-poco/archive/master.zip",
"https://github.com/defold/extension-push/archive/master.zip",
"https://github.com/defold/extension-review/archive/master.zip",
"https://github.com/defold/extension-safearea/archive/master.zip",
"https://github.com/defold/extension-siwa/archive/master.zip",
"https://github.com/defold/extension-videoplayer-native/archive/master.zip",
"https://github.com/defold/extension-webmonetization/archive/master.zip",
"https://github.com/defold/extension-websocket/archive/master.zip",
"https://github.com/defold/extension-webview/archive/master.zip",
"https://github.com/defold/template-native-extension/archive/master.zip",
"https://github.com/britzl/defold-screenshot/archive/master.zip",
"https://github.com/britzl/defold-luasec/archive/master.zip",
"https://github.com/britzl/defold-sharing/archive/master.zip",
"https://github.com/AGulev/DefVideoAds/archive/master.zip",
"https://github.com/subsoap/defos/archive/master.zip",
"https://github.com/Lerg/extension-directories/archive/master.zip",
"https://github.com/dapetcu21/defold-fmod/archive/master.zip",
"https://github.com/GameAnalytics/GA-SDK-DEFOLD/archive/master.zip"
]

failed_tests = []

def test_project(project):
    print("Testing project:", project, os.environ['BUILD_SERVER'], os.environ['PLATFORMS'])
    env = dict(os.environ)
    env['PROJECTS'] = project
    env['HANDLE_ERRORS'] = 'false'

    print("-----------------------------------------------------------------------")
    try:
        p = subprocess.Popen(["./run-tests.sh"], env=env)
        p.wait()
        print("Task finished with return code:", p.returncode)
        if p.returncode:
            failed_tests.append((project, os.environ['PLATFORMS']))
    except Exception as e:
        print(traceback.format_exc())
        print("Task finished with an exception")
        failed_tests.append((project, os.environ['PLATFORMS']))


if __name__ == '__main__':
    if 'PROJECTS' in os.environ:
        PROJECTS =os.environ['PROJECTS'].split(',')

    for project in PROJECTS:
        test_project(project)

    print("-----------------------------------------------------------------------")

    if failed_tests:
        print("Failed projects:")
        for project, platforms in failed_tests:
            print("\t", project, platforms)
        sys.exit(1)


    print("All projects passed")
    sys.exit(0)

