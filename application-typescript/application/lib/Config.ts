import dotenv from 'dotenv';
import { Peer } from './interfaces'

dotenv.config();

export const GATEWAY_PEER: Peer = {
    endpoint: process.env.FABRIC_PEER_ENDPOINT || '',
    hostname: process.env.FABRIC_PEER_HOSTNAME || '',
    mspPath: process.env.FABRIC_PEER_MSP || ''
}

export const NETWORK = {
    channelID: process.env.FABRIC_CHANNEL_ID || '',
    chaincodeID: process.env.FABRIC_CHAINCODE_ID || ''
}

export const DATABASE = {
    url: process.env.FABRIC_DB_LEDGER_URL || '',
    name: process.env.FABRIC_DB_LEDGER_NAME || '',
}

export const CACONFIG = {
    ccpPath: process.env.FABRIC_CCP_PATH || '',
    walletPath: process.env.FABRIC_WALLET_PATH || '',
    asLocalhost: process.env.FABRIC_AS_LOCALHOST || ''
}