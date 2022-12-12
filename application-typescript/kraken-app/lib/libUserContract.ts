/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file A library implementing the API for the smart contract IUser Credentials
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'UserContract';

/* Local */
import {
	connectGateway,
	prettyJSONString,
	prettyJSON,
	getLogger,
} from './libUtil';

import { IUser } from './interfaces';
import { sendTransaction } from './libSignOffline';

/* Constants */
const userContract = 'UserContract';
const createUserTx = 'CreateUser';
const updateUserTx = 'UpdateUser';
const readUserTx = 'ReadUser';
const deleteUserTx = 'DeleteUser';
const getAllUsersTx = 'GetAllUsers';

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc API for the IUser Credentials contract 
 * 
 * @class
 */
export class UserContract {

	channelID: string;
	chaincodeID: string;

	/**
	 * Construct a DataContract object.
	 *
	 * @param {String} channelID - The channel's ID the chaincode is instantiated
	 * @param {String} chaincodeID - The chaincode's ID
	 */
	constructor(channelID: string, chaincodeID: string) {
		this.channelID = channelID;
		this.chaincodeID = chaincodeID;
	}

	/**
	 * Error handler for contract API
	 *
	 * @ignore
	 * @param {Error} e The error object
	 * @param {String} method The function's name
	 */
	handleError(e: any, method: string) {
		logger.error('%s - ', method, e.message);
		throw e;
	}

	/**
	 * Create a new user
	 * Smart contract transaction
	 *
	 * @param {String} userID The user's ID
	 * @param {IUser} IUser The IUser object
	 * @returns null on success, else error
	 */
	async createUser(userID: string, IUser: IUser) {
		const method = 'createUser';
		logger.start(method);

		let res = null;
		// let gateway;

		try {
			// gateway = await connectGateway(userID);
			// const network = await gateway.getNetwork(this.channelID);
			// const contract = network.getContract(this.chaincodeID, userContract);

			const transaction = { fcn: userContract + ':' + createUserTx, args: [prettyJSONString(IUser)] };
			res = await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);
			logger.debug('%s - transaction response: %s', method, res);

			// await contract.submitTransaction(createUserTx, prettyJSONString(IUser));
		} catch (e) {
			res = this.handleError(e, method);
		}

		// if(gateway) {gateway.disconnect();}

		return res;
	}

	/**
	 * Update a user
	 * Smart contract transaction
	 *
	 * @param {String} userID The user's ID
	 * @param {IUser} IUser The IUser object
	 * @returns null on success, else error
	 */
	async updateUser(userID: string, IUser: IUser) {
		const method = 'updateUser';
		logger.start(method);

		let res = null;
		// let gateway;

		try {
			// gateway = await connectGateway(userID);
			// const network = await gateway.getNetwork(this.channelID);
			// const contract = network.getContract(this.chaincodeID, userContract);

			const transaction = { fcn: userContract + ':' + updateUserTx, args: [prettyJSONString(IUser)] };
			res = await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);
			logger.debug('%s - transaction response: %s', method, res);

			// await contract.submitTransaction(updateUserTx, prettyJSONString(IUser));

		} catch (e) {
			res = this.handleError(e, method);
		}

		// if(gateway) {gateway.disconnect();}

		return res;
	}

	/**
	 * Read a user
	 * Smart contract transaction
	 *
	 * @param {String} userID The user's ID
	 * @param {String} username The username to query
	 * @returns {IUser} The IUser Object on success, else error
	 */
	async readUser(userID: string, username: string): Promise<IUser> {
		const method = 'readUser';
		logger.start(method);

		let res = null;
		let gateway;

		try {
			gateway = await connectGateway(userID);
			const network = await gateway.getNetwork(this.channelID);
			const contract = network.getContract(this.chaincodeID, userContract);

			// const transaction = ..
			// logger.debug('%s - transaction: ', transaction);

			res = await contract.evaluateTransaction(readUserTx, username);
			res = prettyJSON(res);
			logger.debug('%s - result user: %s', method, res);
		} catch (e) {
			res = this.handleError(e, method);
		}

		if (gateway) { gateway.disconnect(); }

		return res;
	}

	/**
	 * Delete a user (owner or ADMIN authorized. only owner atm)
	 * Smart contract transaction
	 *
	 * @param {String} userID The user's ID
	 * @param {String} username The username of user to delete
	 * USERNAME IS USED ONLY FOR ADMIN ACCESS.
	 * THE USERNAME AT THE CHAINCODE LEVEL IS OBTAINED FROM
	 * THE CALLER'S CERTIFICATE
	 * @returns {Error} null on success, else error
	 */
	async deleteUser(userID: string, username: string) {
		const method = 'deleteUser';
		logger.start(method);

		let res = null;

		try {
			// gateway = await connectGateway(userID);
			// const network = await gateway.getNetwork(this.channelID);
			// const contract = network.getContract(this.chaincodeID, userContract);

			const transaction = { fcn: userContract + ':' + deleteUserTx, args: [username] };
			logger.debug('%s - %s', method, prettyJSONString(transaction));
			await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);

			// await contract.submitTransaction(deleteUserTx, username);
		} catch (e) {
			res = this.handleError(e, method);
		}

		return res;
	}

	/**
	 * Query all users
	 *
	 * @param {String} clientID The client's ID
	 * @returns {Object} Array of user objects
	 */
	async getUsers(clientID: string): Promise<Array<IUser>> {
		const method = 'getUsers';
		// logger.start(method);

		let res = null;
		let gateway;

		try {
			gateway = await connectGateway(clientID);
			const network = await gateway.getNetwork(this.channelID);
			const contract = network.getContract(this.chaincodeID, userContract);

			// const transaction = ..
			// logger.debug('%s - transaction: ', transaction);

			res = await contract.evaluateTransaction(getAllUsersTx);
			res = prettyJSON(res);
			if (!res) { res = []; }
		} catch (e) {
			res = this.handleError(e, method);
		}

		if (gateway) { gateway.disconnect(); }

		return res;
	}
}


