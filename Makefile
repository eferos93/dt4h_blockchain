.ONESHELL: # Applies to every target in the file!
SHELL := /bin/bash
# .SHELLFLAGS += -e
NETWORK = ./network.sh
APP_PATH = application-typescript
LSB_RELEASE = $(shell lsb_release -cs)
.PHONY: init


# Azure VM, inits external disk also
remote_init_vm:
	- ./tools.sh transferAll .
	- ./tools.sh cmdAll 'sudo apt-get update'
	- ./tools.sh cmdAll 'sudo apt-get install make'
	- ./tools.sh cmdAll 'make init_docker_defaults'
	- ./tools.sh cmdAll 'make init_data_disk DISK=$(DISK)'
	- ./tools.sh cmdAll 'make init_vm'
	- ./tools.sh cmdAll 'make setup'


# n, p, w
init_data_disk:
	- sudo ./scripts/init_vm.sh init_disk -D $(DISK)
	- sudo ./scripts/init_vm.sh mount_disk -D $(DISK)

mount_home_to_disk:
	- sudo ./scripts/init_vm.sh mount_disk -D $(DISK)


init_docker_defaults:
	- sudo ./scripts/init_vm.sh init_docker


init_vm:
	-sudo apt-get update
	-sudo apt-get install apt-transport-https ca-certificates curl lsb-release -y
	-curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	-echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(shell lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	-sudo apt-get update 
	-sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose -y
	-sudo apt-get install python3-pip jq tree -y
	-pip3 install yq==2.12.0
	-sudo usermod -aG docker ${USER}
	echo "Relogin to VM for docker permissions to take effect." 


setup: 
	./tools.sh setup

setup_files:
	-mkdir logs
	./tools.sh switchNet dev

init: setup_files init_network init_application

init_network:
	${NETWORK} up

init_application:
	pushd ${APP_PATH} || exit 1
	npm run gen_mod
	npm run init
	popd

start:
	${NETWORK} start

stop:
	${NETWORK} stop

addorg:
	${NETWORK} addorg

restart:
	sudo ${NETWORK} down 
	${NETWORK} up 

remake_certs:
	${NETWORK} rm
	${NETWORK} remake_certs

.PHONY: clean
clean:
	${NETWORK} down

test: init
	pushd ${APP_PATH} || exit 1
	npm run test
	popd
