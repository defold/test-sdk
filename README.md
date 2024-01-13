[![Actions Status Alpha](https://github.com/defold/test-sdk/actions/workflows/test-alpha.yml/badge.svg)](https://github.com/defold/test-sdk/actions)
[![Actions Status Beta](https://github.com/defold/test-sdk/actions/workflows/test-beta.yml/badge.svg)](https://github.com/defold/test-sdk/actions)
[![Actions Status Stable](https://github.com/defold/test-sdk/actions/workflows/test-stable.yml/badge.svg)](https://github.com/defold/test-sdk/actions)

# test-sdk


## How to test locally


`PROJECTS` is a comma separated list.

    BUILD_SERVER=http://localhost:9010 PROJECTS=https://github.com/defold/extension-webview/archive/master.zip SHA1=74f260242b3a3f16a0aa38889dc5147c5567864a ./run-tests.sh x86_64-macos
