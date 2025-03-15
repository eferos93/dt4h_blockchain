import { promises as fs } from 'fs';
import * as path from 'path';
import * as grpc from '@grpc/grpc-js';
import { connect, Contract, Gateway, Identity } from '@hyperledger/fabric-gateway';
import * as crypto from 'crypto';

let gateway: Gateway | null = null;
let contract: Contract | null = null;
let client: grpc.Client | null = null;

/**
 * Check if connected to Hyperledger Fabric network
 */
export const isConnected = (): boolean => {
  return gateway !== null && contract !== null;
};

/**
 * Connect to the Hyperledger Fabric network using the provided certificate and private key
 */
export const connectToNetwork = async (certPath: string, keyPath: string): Promise<void> => {
  try {
    // The gRPC client connection should be shared by all Gateway connections to this endpoint
    const peerEndpoint = 'localhost:7051'; // Replace with your peer endpoint
    client = await newGrpcConnection(peerEndpoint);

    // Load the certificate and private key
    const credentials = await loadCredentials(certPath, keyPath);
    
    // Identity to use for signing transactions
    const identity: Identity = {
      mspId: 'Org1MSP', // Replace with your MSP ID
      credentials: credentials,
    };

    gateway = connect({
      client,
      identity,
      signer: await newSigner(keyPath),
    });

    // Get network and contract
    const network = gateway.getNetwork('mychannel'); // Replace with your channel name
    contract = network.getContract('mycontract'); // Replace with your contract/chaincode name
    
    console.log('Successfully connected to Hyperledger Fabric network');
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
    contract = null;
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
async function newGrpcConnection(endpoint: string): Promise<grpc.Client> {
  // Use TLS if the peer requires it
  const tlsRootCert = await fs.readFile('path/to/tls/ca.crt'); // Replace with your TLS CA cert path
  const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
  
  return new grpc.Client(endpoint, tlsCredentials, {});
}

/**
 * Execute a query on the ledger
 */
export const executeQuery = async (queryString: string): Promise<any> => {
  if (!isConnected() || !contract) {
    throw new Error('Not connected to Hyperledger Fabric network');
  }
  
  try {
    // Submit a transaction to the ledger with query
    const resultBytes = await contract.evaluateTransaction('query', queryString);
    const resultJson = Buffer.from(resultBytes).toString('utf8');
    return JSON.parse(resultJson);
  } catch (error) {
    console.error('Failed to execute query:', error);
    throw error;
  }
};

/**
 * Get history for a key
 */
export const getQueryHistory = async (key: string): Promise<any> => {
  if (!isConnected() || !contract) {
    throw new Error('Not connected to Hyperledger Fabric network');
  }
  
  try {
    // Get transaction history for a key
    const resultBytes = await contract.evaluateTransaction('getHistory', key);
    const resultJson = Buffer.from(resultBytes).toString('utf8');
    return JSON.parse(resultJson);
  } catch (error) {
    console.error('Failed to get history:', error);
    throw error;
  }
};