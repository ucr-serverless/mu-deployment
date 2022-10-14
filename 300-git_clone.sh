
#!/bin/bash
mount_path=$MYMOUNT

if [[ $mount_path == "" ]]
then
	echo MYMOUNT env var not defined
	exit 1
fi

pushd $mount_path

# get Istio
git clone --recursive https://github.com/ucr-serverless/mu-istio.git istio
pushd istio
git checkout mu
rm -rf api
git clone https://github.com/ucr-serverless/mu-istio-api.git api
popd

# get Envoy
git clone https://github.com/ucr-serverless/mu-envoy-load-balancer.git lb-envoy-wasm
pushd lb-envoy-wasm
git checkout mu
popd

# get proxy
git clone https://github.com/ucr-serverless/mu-istio-proxy.git proxy
pushd proxy
git checkout mu
popd

# get knative-serving
mkdir -p ${GOPATH}/src/knative.dev
pushd ${GOPATH}/src/knative.dev
SERVING_FILE_NAME=serving
git clone https://github.com/ucr-serverless/mu-kn-serving.git ${SERVING_FILE_NAME}
pushd ${SERVING_FILE_NAME}
git checkout autoscaler
popd

# return to script dir
popd
