/**
 *
 * @file A wrapper for the fabric-gateway connection
 * @author Alexandros Tragkas
 */

import { ConnectOptions, Identity, Signer, signers, connect, Contract, GrpcClient, Gateway } from '@hyperledger/fabric-gateway';
import * as grpc from '@grpc/grpc-js';
import * as crypto from 'crypto';
import * as path from 'path';
import { promises as fs } from 'fs';
import { TextDecoder } from 'util';
import { Peer, IClient } from './interfaces'
import { getLogger } from './libUtil'

const utf8Decoder = new TextDecoder();
const logger = getLogger('Connection')

/**
 * This class provides methods for handling connections to a Fabric network.
 * @class Connection
 */
export class Connection {
    
    constructor() {}

    /**
     * Transforms the result from a contract transaction to a readable format and logs it.
     * 
     * @param {Object} contract - The smart contract to be invoked.
     * @param {string} func - The name of the function in the smart contract to be invoked.
     * @param {...any} args - The arguments for the function to be invoked.
     * @returns {Promise<void>}
     */
    async call(contract: Contract, func: string, ...args: any): Promise<void> {
        const putResult = await contract.submitTransaction(func, ...args);
        console.log('Put result:', utf8Decoder.decode(putResult));
    }
    
    /**
     * Connects to a Fabric Gateway.
     * @async
     * @param {GrpcClient} peerClient - The client to connect.
     * @param {IClient} client - Client interface.
     * @returns {Promise<Gateway>} The connected Gateway.
     */
    async connectGateway(peerClient: GrpcClient, client: IClient): Promise<Gateway> {
        const connectOptions = await this.newConnectOptions(peerClient, client)
        return connect(connectOptions)
    }

    /**
     * Disconnects from a Fabric Gateway.
     * @async
     * @param {Gateway} gateway - The Gateway to disconnect.
     * @returns {Promise<void>} Nothing
     */
    async disconnectGateway(gateway: Gateway) {
        try {        
            return gateway.close()
        } catch (e) {
            return null
        }        
    }

    /**
     * Disconnects a gRPC client.
     * @async
     * @param {GrpcClient} client - The client to disconnect.
     * @returns {Promise<void>} Nothing
     */
    async disconnectClient(client: GrpcClient) {
        try {        
            return client.close()
        } catch (e) {
            return null
        }        
    }
    
    /**
     * Creates a new gRPC client connection to a peer
     * 
     * @param {Peer} peer - The peer to connect to.
     * @returns {Promise<grpc.Client>} The gRPC client.
     */
    async newGrpcConnection(peer: Peer): Promise<grpc.Client> {
        const method = 'newGrpcConnection'
        logger.debug(`${method} - Connecting to peer: ${peer.hostname}`)
        const tlsCertPath = `${peer.mspPath}/tls/tlscacerts/ca.crt`
        const tlsRootCert = await fs.readFile(tlsCertPath);
        const tlsCredentials = grpc.credentials.createSsl(tlsRootCert);
        return new grpc.Client(peer.endpoint, tlsCredentials, {
            'grpc.ssl_target_name_override': peer.hostname,
        });
    }
    
    /**
     * Connects to a Fabric peer using gRPC.
     * @async
     * @param {Peer} peer - The peer to connect.
     * @returns {Promise<grpc.Client>} The connected client.
     */
    async newConnectOptions(peerClient: GrpcClient, client: IClient): Promise<ConnectOptions> {
        return {
            client: peerClient,
            identity: await this.newIdentity(client),
            signer: await this.newSigner(client),
            // Default timeouts for different gRPC calls
            evaluateOptions: () => {
                return { deadline: Date.now() + 5000 }; // 5 seconds
            },
            endorseOptions: () => {
                return { deadline: Date.now() + 15000 }; // 15 seconds
            },
            submitOptions: () => {
                return { deadline: Date.now() + 5000 }; // 5 seconds
            },
            commitStatusOptions: () => {
                return { deadline: Date.now() + 60000 }; // 1 minute
            },
        };
    }
    
    /**
     * Creates an Identity object.
     * @async
     * @param {IClient} client - Client interface.
     * @returns {Promise<Identity>} The Identity object.
     */
    async newIdentity(client: IClient): Promise<Identity> {
        if (client?.x509Identity) {

            return { 
                mspId: client.x509Identity.mspId, 
                credentials: new Uint8Array(Buffer.from(client.x509Identity.credentials.certificate, 'utf-8')) 
            }
        }
        const certPath = `${client.mspPath}/msp/signcerts/cert.pem`
        const cert = await fs.readFile(certPath);
        // @ts-ignore
        return { mspId: client.mspId, credentials: cert };
    }
    
    /**
     * Creates a Signer object.
     * @async
     * @param {IClient} client - Client interface.
     * @returns {Promise<Signer>} The Signer object.
     */
    async newSigner(client: IClient): Promise<Signer | undefined> {
        if (client?.x509Identity) {
            if (!client.x509Identity.credentials?.privateKey) return undefined
            const privateKeyPem = Buffer.from(client.x509Identity.credentials.privateKey, 'utf-8')
            const privateKey = crypto.createPrivateKey(privateKeyPem);
            return signers.newPrivateKeySigner(privateKey)
        }
        const keystorePath = `${client.mspPath}/msp/keystore`
        const keyFiles = await fs.readdir(`${keystorePath}`);
        if (keyFiles.length === 0) {
            // return undefined
            throw new Error(`No private key files found in directory ${client.mspPath}`);
        }
        const keyPath = path.resolve(keystorePath, keyFiles[0]);
        const privateKeyPem = await fs.readFile(keyPath);
        const privateKey = crypto.createPrivateKey(privateKeyPem);
        return signers.newPrivateKeySigner(privateKey);
    }

}

export default new Connection()