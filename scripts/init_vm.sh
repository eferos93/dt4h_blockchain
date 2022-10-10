#!/bin/bash

init_data_disk() {
	echo "Initializing DATA disk"

	[ -z "$DISK_CODE" ] && echo "Missing disk name" && exit 1
	DISK_PART=${DISK_CODE}1
	
	dmesg | grep SCSI | grep $DISK_CODE
	res=$?
	if [[ $res -eq  1 ]]; then
		echo "Error, extra DATA disk not found."
		exit 1
	fi

	lsblk | grep $DISK_PART
	res=$?

	if [ $res -eq 0 ]; then
		echo "Disk already partitioned. Exiting..."
		exit 1
	fi

	echo
	echo
	echo " #################### "
	echo
	echo " TYPE n, p, w FOR DISK INITIALIZATION."
	echo
	echo " #################### "
	echo
	echo
	set -x
	sudo fdisk /dev/$DISK_CODE
	set +x

	set -x
	sudo mkfs -t ext4 /dev/${DISK_PART}
	set +x
	echo "Disk initialized"

}


mount_home_to_disk() {
	[ -z "$DISK_CODE" ] && echo "Missing disk name" && exit 1
	DISK_PART=${DISK_CODE}1
	
	echo "Mounting /home to drive ${DISK_PART}"
	sudo mount /dev/${DISK_PART} /mnt
	sudo cp -rp /home/* /mnt
	sudo mv /home /home.orig
	echo "Copy of /home saved to /home.orig"
	
	sudo mkdir /home
	sudo umount /dev/${DISK_PART}
	sudo mount /dev/${DISK_PART} /home/
	echo "Mounted /dev/${DISK_PART} to /home"

	echo "Editing /etc/fstab to automount /home to /dev/${DISK_PART}"
	if [ ! -f /etc/fstab/fstab.orig ]; then
		sudo cp /etc/fstab /etc/fstab.orig
		echo "Copy of /etc/fstab saved to /etc/fstab.orig"
	fi
	fstab_log="/dev/${DISK_PART}\t/home\text4\tdefaults\t0\t0"
	sudo echo -e $fstab_log >> /etc/fstab
}


setup_docker_defaults() {
	sudo systemctl stop docker
	sudo systemctl stop docker.socket
	sudo systemctl stop containerd

	FILE=/etc/docker/daemon.json
	echo '{
	"data-root": "/home/'${SUDO_USER}'/docker",
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "100m",
		"max-file": "20"
	}
}
' > $FILE
	sudo systemctl start docker
	docker info -f '{{ .DockerRootDir}}'
}


# Parse input
if [[ $# -lt 1 ]]; then
	echo "Missing command"
	exit 1
else
	MODE="$1"
fi

if [ $# -ge 1 ]; then
	if [ "$MODE" == "init_disk" ]; then
		cmd=init_data_disk
	elif [ "$MODE" == "init_docker" ]; then
		cmd=setup_docker_defaults
	elif [ "$MODE" == "mount_disk" ]; then
		cmd=mount_home_to_disk
	else
		echo "Command not found."
		exit 1
	fi
fi

while [[ $# -ge 1 ]]; do
	key=$1
	case $key in
	-D|--disk )
		export DISK_CODE=$2
		;;
	esac
	shift
done

$cmd