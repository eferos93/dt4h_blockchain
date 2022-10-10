#!/bin/bash

# . configCC.sh
. util.sh
. configGlobals.sh

for f in ${FABRIC_CA_API}/*; do source $f; done

usage() {
	echo -e "Perform CA operations"
	echo 
	echo -e "Usage:"
	echo -e " ./clientCA.sh [command] [flags]"
	echo 
	echo -e "Available commands:"
	echo -e "  register \t Registers a user/node to TLS and ECERT CAs"
	echo -e "  enroll \t Enrolls a user/node to obtain TLS and ECERT MSP"
	echo -e "  reenroll \t Renrolls a user/node to renew Certificate"
	echo -e "  identitylist \t List identities"
	echo -e "  setup_orgca \t Setup and launch TLS/CA Server"
	echo -e "  setup_orgmsp \t Setup Org Admin (MSP)"
	echo -e "  setup_orgops \t Setup and launch Operations TLS Server"
	echo -e "  regen_ops \t Enroll an Operations Client to monitor nodes securely"
	echo -e "  gencrl \t Generate CRL for org, use -U for users CRL"
	echo -e "  start \t Start Docker CA Container"
	echo -e ""
	echo -e "Flags:"
	echo -e "  -h <help> \t\t Print help message"
	echo -e "  -o <org> \t\tName of organization"
	echo -e "  -u <username> \t ID of user, e.g peer0, orderer0"
	echo -e "  -s <secret> \t\t Password of enrollment"
	echo -e "  -t <type> \t\t Type of org, e.g peer, orderer"
	echo -e "  -p <port> \t\t Port of CA, defaults to caPort"
	echo -e "  -T <tls> \t\t Use TLS CA server"
	echo -e "  -U <users> \t\t Use org-users CA"
	echo -e "  -N <caname> \t\t Name of CA e.g ca-org"
	echo -e "  -c <catype> \t\t ca/tls/tlsops"
	echo ""
	echo -e "Examples:"
	echo -e "  ./clientCA.sh register -t peer -u peer0 -o org1 -s secret123"
	echo -e "  ./clientCA.sh enroll -t peer -u peer0 -o org1 -s secret123"
	echo -e "  ./clientCA.sh reenroll -t peer -u peer0 -o org1"
	echo -e "  ./clientCA.sh identitylist -o org1 [-T] [-U]"
	echo -e "  ./clientCA.sh setup_orgca -o org3"
	echo -e "  ./clientCA.sh setup_orgmsp -o org3 -t peer"
	echo -e "  ./clientCA.sh gencrl -o org [-U]"
	echo ""
}


# Parse input
if [ $# -lt 1 ]; then
	usage
	exit 1
	return
else
	MODE="$1"
fi

if [[ $# -ge 1 ]] ; then
	if [ "$MODE" == "register" ]; then
		cmd=register
	elif [ "$MODE" == "enroll" ]; then
		cmd=enroll
	elif [ "$MODE" == "reenroll" ]; then
		cmd=reenroll		
	elif [ "$MODE" == "identitylist" ]; then
		cmd=identityList	
	elif [ "$MODE" == "setup_orgca" ]; then
		cmd="createTLSCA;createCA"
	elif [ "$MODE" == "setup_idca" ]; then
		cmd=createCA
	elif [ "$MODE" == "setup_orgops" ]; then
		cmd=createTLSOpsCA
	elif [ "$MODE" == "setup_orgmsp" ]; then
		cmd="registerOrgAdmin;enrollOrgAdmin"
	elif [ "$MODE" == "enrollorgadmin" ]; then
		cmd="enrollOrgAdmin"
	elif [ "$MODE" == "regen_ops" ]; then
		cmd=regenOps
	elif [ "$MODE" == "gencrl" ]; then
		cmd=gencrl
	elif [ "$MODE" == "start" ]; then
		cmd=startServer
	else
		usage
		exit 1
		return
	fi
	shift
fi


while [[ $# -ge 1 ]]; do
	key=$1
	case $key in
	-h|--help )
		usage
		exit 0	
		;;
	-o|--org )
		export ORG_NAME="${2,,}"
		export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-client-${ORG_NAME}
		export FABRIC_CA_SERVER_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-tlsca-server-${ORG_NAME}
		;;
	-u|--username )
		export USERNAME=$2
		;;	
	-s|--secret )
		export SECRET=$2
		;;
	-t|--type )
		export TYPE=$2
		;;	
	-p|--port )
		export PORT=$2
		;;
	-T|--tls )
		export TLS=true
		;;	
	-U|--users )
		export USERS=true
		;;	
	-M|--msp )
		export CAMSPDIR=$2
		;;
	--reuse-key )
		export REUSE_KEY="--csr.keyrequest.reusekey"
		;;
	-c|--catype )
		case $2 in
			ca|tls|tlsops ) 
				export CA_TYPE=$2
				;;
			* )
				printError "Value of -c should be one of ca/tls/tlsops"
				exit 1
				;;
		esac
		;; 
	esac
	shift
done

export FABRIC_CA_CLIENT_HOME=${FABRIC_CA_PATH}/${ORG_NAME}/fabric-ca-client-${ORG_NAME}
export TLS_ROOTCERT_PATH=${FABRIC_CA_CLIENT_HOME}/tls-root-cert/tls-ca-cert.pem

[ ! -z $USERS ] && export CA_NAME=ca-${ORG_NAME}-users
[ -z $CAMSPDIR ] && [ ! -z $USERS ] && export CAMSPDIR="$FABRIC_CA_CLIENT_HOME"/${ORG_NAME}-users-ca/userscaadmin/msp
[ -z $CAMSPDIR ] && [ -z $USERS ] && export CAMSPDIR="$FABRIC_CA_CLIENT_HOME"/${ORG_NAME}-ca/rcaadmin/msp

# set -x
eval $cmd
# set +x