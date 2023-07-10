#!/bin/bash

VERSION=${FABRIC_TAG}
# if ca version not passed in, default to latest released version
CA_VERSION=${CA_TAG}
ARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')")
BINARY_FILE=hyperledger-fabric-${ARCH}-${VERSION}.tar.gz
CA_BINARY_FILE=hyperledger-fabric-ca-${ARCH}-${CA_VERSION}.tar.gz

setup() {
	printInfo "Setting up Binaries, Docker Images and Golang..."
	yes | apt install libtool libltdl-dev

	mkdir logs
	pushd ./scripts || exit
	
	# Install GO
	set -x
	go version
	res=$?
	set +x
	if [ $res -ne 0 ]; then
		echo "GO not found. Installing..."
		./goinstall.sh
		source ~/.bashrc
	else
		printSuccess "GO already installed. Skipping..."
	fi

	# Install FABRIC binaries and Images
	./downloadFabric.sh -s
	docker pull hyperledger/fabric-ca:${CA_TAG}
	if [ $? -ne 0 ]; then
        printError 'Exiting due to setup failure...'
		return -1
    fi

	rm -rf ${FABRIC_HOME}/bin

	if [ -d "bin" ]; then
		mv bin ${FABRIC_HOME}
	else
		pwd
		tar xvfz ${BINARY_FILE}
		res=$?
		if [ $res -eq 0 ]; then
			rm ${BINARY_FILE}
		fi

		mv bin ${FABRIC_HOME}
		rm -rf bin config

		tar xvfz ${CA_BINARY_FILE}
		res=$?
		if [ $res -eq 0 ]; then
			rm ${CA_BINARY_FILE}
		fi
		
		mv bin/* ${FABRIC_HOME}/bin
		rm -rf bin config
	fi

	popd
	chmod -R u+x bin
	printInfo 'Downloaded Fabric successfully!'
}
