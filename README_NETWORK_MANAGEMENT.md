## Project Overview

This project utilizes the Hyperledger Fabric framework to manage a permissioned blockchain network. The primary setup and management of the network are facilitated by a series of bash scripts, all managed by `network.sh`, which allows for both a full setup and a step-by-step setup process.

This file provides a streamlined and robust guide for managing the project on the current virtual machine, where the environment has already been set up. This README serves as a more up-to-date reference than the main README file, particularly for network setup and management. The engineer responsible for this project should prioritize following the instructions here to get the network operational. For additional details on the project's features and architecture, refer to the main README file, but disregard the installation and initial network setup sections, as they may not reflect the current project stage on this server.

---

## Setup Instructions

1. **Starting the Network:**
   - To bring the network up in one command, use:
     ```bash
     sudo ./network.sh up
     ```
   - Alternatively, the setup can be run step-by-step:
     - Run each of the following commands sequentially:
       ```bash
       sudo ./network.sh step1
       ./network.sh step2
       ./network.sh step3
       ./network.sh step4
       sudo ./network.sh step5
       sudo ./network.sh step6
       sudo ./network.sh step7
       ```
   - Step 1 and Steps 5 through 7 require `sudo` privileges for successful completion.
   - To shut down the network, use:
     ```bash
     sudo ./network.sh down
     ```

2. **Server Restart Requirements:**
   - After a server restart, verify that the Docker DNS servers are configured correctly.
   - Update the Docker DNS settings in the `/etc/docker/daemon.json` file. If this file does not exist, create it and add the following configuration:
     ```json
     {
       "dns": ["8.8.8.8", "8.8.4.4"]
     }
     ```
   - Restart the Docker daemon to apply these settings.
