#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script provides functionality to configure hosts for Fabric nodes to communicate

# Configure IPs and append to /etc/hosts
configHosts() {
  printInfo "Configuring hosts..."
  findStandardHosts
  echo "$standard_hosts" > /etc/hosts
  echo "${HOSTS}" >> /etc/hosts
  [ ! $? ] && echo "${HOSTS}"
}

findStandardHosts() {
  local skip=0
  standard_hosts=""
  while IFS= read -r line; do
    if [ "$line" ==  "# Hyperledger Fabric Host Configuration" ]; then
      skip=1
      continue
    fi

    if [ "$line" == "# end" ]; then
      skip=0
      continue
    fi 

    if [ -z "$line" ]; then 
      continue;
    fi
    
    if [ "$skip" -eq 0 ]; then
      standard_hosts+="$line"
      standard_hosts+=$'\n'
    fi

  done < /etc/hosts
}
