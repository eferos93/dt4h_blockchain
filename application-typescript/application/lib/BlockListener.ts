/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import * as grpc from '@grpc/grpc-js';
import { ChaincodeEvent, CloseableAsyncIterable, GrpcClient, Gateway, GatewayError, Network } from '@hyperledger/fabric-gateway';
import { TextDecoder } from 'util';
import Connection from './Connection'
import { IClient } from './interfaces'
import { OffchainDB } from './ReplicateDB';
import { getLogger } from './libUtil';

/* Logging */
const logger = getLogger('BlockListener');

const offchainDB = new OffchainDB();
const utf8Decoder = new TextDecoder();

/**
 * Class to listen and handle block events.
 */
export class BlockListener {
    
    private peerConnection: GrpcClient;
    private channelID: string;
    private chaincodeID: string;
    private network: Network;
    private gateway: Gateway;
    private client: IClient;

    /**
     * Create a new BlockListener.
     * @param {GrpcClient} peerConnection - The peer connection.
     * @param {IClient} client - The client instance.
     */
    constructor(peerConnection: GrpcClient, client: IClient) {
        this.peerConnection = peerConnection
        this.client = client
    }
    
    /**
     * Initialize the BlockListener.
     * @param {string} channelID - The channel ID.
     * @param {string} chaincodeID - The chaincode ID.
     */
    async init(channelID: string, chaincodeID: string): Promise<void> {
        this.channelID = channelID
        this.chaincodeID = chaincodeID
        this.gateway = await Connection.connectGateway(this.peerConnection, this.client)
        this.network = this.gateway.getNetwork(this.channelID)
        await offchainDB.connect()
    }

    /**
     * Run the BlockListener.
     */
    async run(): Promise<void> {
        let events: CloseableAsyncIterable<ChaincodeEvent> | undefined;
    
        try {
            events = await this.network.getChaincodeEvents(this.chaincodeID);
            await this.replayChaincodeEvents(BigInt(0));
        } finally {
            events?.close();
            this.gateway.close();
        }
    }

    /**
     * Read events from the chaincode.
     * @param {CloseableAsyncIterable<ChaincodeEvent>} events - The chaincode events.
     */
    async readEvents(events: CloseableAsyncIterable<ChaincodeEvent>): Promise<void> {
        try {
            for await (const event of events) {
                const payload = this.parseJson(event.payload);
                console.log(`\n<-- Chaincode event received: ${event.eventName} -`, payload);
            }
        } catch (error: unknown) {
            if (!(error instanceof GatewayError) || error.code !== grpc.status.CANCELLED) {
                throw error;
            }
        }
    }
    
    /**
     * Parse JSON from the provided Uint8Array.
     * @param {Uint8Array} jsonBytes - The JSON bytes.
     * @return {unknown} The parsed JSON.
     */
    parseJson(jsonBytes: Uint8Array): unknown {
        const json = utf8Decoder.decode(jsonBytes);
        return JSON.parse(json);
    }
    
    /**
     * Replay chaincode events from the specified start block.
     * @param {bigint} startBlock - The block to start replaying from.
     */
    async replayChaincodeEvents(startBlock: bigint): Promise<void> {
        const method = 'replayChaincodeEvents'

        const events = await this.network.getChaincodeEvents(this.chaincodeID, {
            startBlock,
        });
    
        try {
            for await (const event of events) {
                try {
                    const payload = this.parseJson(event.payload);
                    console.log(`\n<-- Chaincode event replayed: ${event.eventName} -`, payload);
                    await offchainDB.eventHandler(event.eventName, payload);
                } catch(e) {
                    console.log(e)
                    logger.error(`${method} - ${e}`)
                }
            }
        } finally {
            events.close();
        }
    }
}

export default BlockListener
