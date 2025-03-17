import { promises as fs } from 'fs';
import * as path from 'path';
import * as grpc from '@grpc/grpc-js';
import { connect, Contract, Gateway, Identity, Network } from '@hyperledger/fabric-gateway';
import * as crypto from 'crypto';

let gateway: Gateway | null = null;
// let contract: Contract | null = null;
let client: grpc.Client | null = null;
let network: Network | null = null;

interface NetworkSetup {
  peerEndpoint: string,
  tlsRootCertPath: string,
  mspId: string,
  channelName: string
}

/**
 * Check if connected to Hyperledger Fabric network
 */
export const isConnected = (): boolean => {
  return gateway !== null && network !== null;
};

/**
 * Connect to the Hyperledger Fabric network using the provided certificate and private key
 */
export const connectToNetwork = async (certPath: string, keyPath: string, config: NetworkSetup): Promise<void> => {
  try {
    // The gRPC client connection should be shared by all Gateway connections to this endpoint
    // const peerEndpoint = envOrDefault('PEER_ENDPOINT', 'localhost:7051'); 
    
    client = await newGrpcConnection(config.peerEndpoint, config.tlsRootCertPath);

    // Load the certificate and private key
    const credentials = await loadCredentials(certPath, keyPath);
    
    // Identity to use for signing transactions
    const identity: Identity = {
      mspId: config.mspId, 
      credentials: credentials,
    };

    gateway = connect({
      client,
      identity,
      signer: await newSigner(keyPath),
    });

    // Get network and contract
    network = gateway.getNetwork(config.channelName);
    // return network;
  } catch (error) {
    // Clean up on error
    if (gateway) {
      gateway.close();
      gateway = null;
    }
    if (client) {
      client.close();
      client = null;
    }
    // contract = null;
    throw error;
  }
};

/**
 * Load credentials from certificate and private key files
 */
async function loadCredentials(certPath: string, keyPath: string): Promise<Uint8Array> {
  // Load certificate
  const certificate = await fs.readFile(certPath);
  return certificate;
}

/**
 * Create a new signer from the private key
 */
async function newSigner(keyPath: string): Promise<any> {
  const privateKeyPem = await fs.readFile(keyPath);
  const privateKey = crypto.createPrivateKey(privateKeyPem);
  
  return {
    sign: async (digest: Uint8Array): Promise<Uint8Array> => {
      const signature = crypto.sign(undefined, Buffer.from(digest), privateKey);
      return Uint8Array.from(signature);
    }
  };
}

/**
 * Create a new gRPC connection to the peer
 */
async function newGrpcConnection(endpoint: string, tlsRootCertPath: string): Promise<grpc.Client> {
  // Use TLS if the peer requires it
  const tlsRootCert = await fs.readFile(tlsRootCertPath); // Replace with your TLS CA cert path
  const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
  
  return new grpc.Client(endpoint, tlsCredentials, {});
}

/**
 * Execute a query on the ledger
 */
export const executeQuery = async (queryString: string): Promise<string> => {
  if (!isConnected() || !network) {
    throw new Error('Not connected to Hyperledger Fabric network');
  }
  
  try {
    const contract = network.getContract('dt4hCC') //TODO: see correct chaicode name
    // Submit a transaction to the ledger with query
    const resultBytes = await contract.evaluateTransaction('LogQuery', queryString);
    const resultJson = Buffer.from(resultBytes).toString('utf8');
    return resultJson;
  } catch (error) {
    console.error('Failed to execute query:', error);
    throw error;
  }
};

/**
 * Get history for a key
 */
export const getQueryHistory = async (key: string): Promise<any> => {
  if (!isConnected() || !network) {
    throw new Error('Not connected to Hyperledger Fabric network');
  }
  
  try {
    // Get transaction history for a key
    const contract = await network.getContract('dt4hCC') //TODO: check contract name 
    const resultBytes = await contract.evaluateTransaction('GetUserHistory', key);
    const resultJson = Buffer.from(resultBytes).toString('utf8');
    return JSON.parse(resultJson);
  } catch (error) {
    console.error('Failed to get history:', error);
    throw error;
  }
};

function envOrDefault(key: string, defaultValue: string): string {
  return process.env[key] || defaultValue;
}