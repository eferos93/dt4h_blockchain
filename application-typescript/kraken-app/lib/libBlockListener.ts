/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file A library implementing the block listening and event handling
 * @module libBlockListener
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'BlockListener';

/* Dependencies */
import * as fs from 'fs';
import * as process from 'process';

/* Local */
import * as Util from './libUtil';
import { OffchainDB } from './libReplicateDB';

/* Env */
const blockPath: string = process.env.BLOCK_PATH!;

/* Logging */
const logger = Util.getLogger(TYPE);

/* Init */
var offchainDB = new OffchainDB();

/**
 * Handle the event's transaction data
 *
 * @async
 * @param {Object} transactionData The data of event
 * @param {number} blockNum The current block number
 */
async function handleTransactionData(transactionData: any, blockNum: number) {
	const method = 'handleTransactionData';

	try {
		// TRANSACTION PROPOSAL RESPONSE PAYLOAD
		const transactionPayload = transactionData.actions[0].payload.action.proposal_response_payload;
		const eventName = transactionPayload.extension.events.event_name;
		
		// RESPONSE STATUS OF TRANSACTION
		const response = transactionPayload.extension.response;

		// EVENT RESULT
		let eventResult = transactionPayload.extension.events.payload;

		// console.info('Transaction event result');
		if (eventResult.toString() === null ||
			eventResult.toString() === undefined ||
			!eventResult.toString())
		{return;}

		if (response.status !== 200) {
			console.log('Block was not committed');
			return;
		}

		logger.info('%s - passing event to DB: ', method, eventName);
		return await offchainDB.eventHandler(eventName, eventResult);
		// const chaincode = transactionData.actions[0].payload.chaincode_proposal_payload.input.chaincode_spec;
	} catch(e: any) {
		logger.error('%s - ', method, e.message);
	}
}

/**
 * Create a listener for blocks
 * to extract the transaction data
 *
 * @param {String} userID The user's id from wallet
 * @param {String} channelID The channel name
 * @returns {Listener} The block listener object
 */
export async function createBlockListener(userID: string, channelID: string) {
	const method = 'createBlockListener';
	logger.start(method);

	try {
		
		await offchainDB.connect();
		let users = await offchainDB.users.getAll()

		const gateway = await Util.connectGateway(userID);
		logger.debug('%s - %s - %s ', method, userID, channelID);
		const network = await gateway.getNetwork(channelID);

		let listener = async(event: any) => {
			const timestamp = event.blockData.data.data[0].payload.header.channel_header.timestamp;
			const blockNum = Number(event.blockNumber);
			const transEvents = event.getTransactionEvents();

			for (let transEvent of transEvents) {
				if (transEvent.isValid){
					transEvent.transactionData.timestamp = timestamp;
					await handleTransactionData(transEvent.transactionData, blockNum);
				}
			}

			fs.writeFileSync(blockPath, (blockNum + 1).toString());
		};
		const nextBlock = Number(fs.readFileSync(blockPath, 'utf-8'));
		const options = {
			startBlock: nextBlock
		};

		await network.addBlockListener(listener, options);
		return listener;
	} catch(e: any) {
		logger.error('%s - ', method, e);
		throw e;
	}

}

/**
 * Remove block listener
 *
 * @param {String} userID The user's id from wallet
 * @param {String} channelID The channel name
 * @param {Listener} listener The listener to remove
 */
export async function removeBlockListener(userID: string, channelID: string, listener: any) {
	const method = 'removeBlockListener';
	logger.start(method);

	const gateway = await Util.connectGateway(userID);
	try {
		// await offchainDB.disconnect();
		const network = await gateway.getNetwork(channelID);

		return await network.removeBlockListener(listener);
	} catch(e) {
		logger.error('%s - ', method, e);
	} finally {
		if(gateway) {gateway.disconnect()}
	}
}

