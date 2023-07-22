/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file A library implementing the API for the smart contract User Credentials
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
	bufferToJson
} from './libUtil';

import { IUser } from './interfaces';
import { Contract } from '@hyperledger/fabric-gateway'
import Transaction from './Transactions'

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc API for the IUser Credentials contract 
 * 
 * @class
 */
export class UserContract {

	// channelID: string;
	// chaincodeID: string;
	contract: Contract;
	
	constructor(contract: Contract) {
		this.contract = contract
	}

	/**
	 * Logs an error message and rethrows the error.
	 * 
	 * @param error The error that was caught
	 * @param method The name of the method where the error occurred
	 * @throws {Error}
	 */
	handleError(error: Error, method: string): never {
		logger.error('%s - %j', method, error.message);
		console.log(error)
		throw error;
	}

	/**
	 * Create a new user
	 * Smart contract transaction
	 *
	 * @param {IUser} user The IUser object
	 * @returns null on success, else error
	 */
	async createUser(user: IUser) {
		const method = 'createUser';

		try {
			const transaction = Transaction.user.create(user)
			return await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
		} catch (error: any) {
			this.handleError(error, method);
		}
	}

	/**
	 * Update a user
	 * Smart contract transaction
	 *
	 * @param {IUser} user The IUser object
	 * @returns null on success, else error
	 */
	async updateUser(user: IUser) {
		const method = 'updateUser';

		try {
			const transaction = Transaction.user.update(user)
			return await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
		} catch (error: any) {
			this.handleError(error, method);
		}
	}

	/**
	 * Read a user
	 * Smart contract transaction
	 *
	 * @param {String} username The username to query
	 * @returns {IUser} The IUser Object on success, else error
	 */
	async readUser(username: string): Promise<IUser> {
		const method = 'readUser';

		try {
			const transaction = Transaction.user.read(username)
			const res = await this.contract.evaluateTransaction(transaction.name, ...transaction.options!.arguments);
			return res?.length ? bufferToJson(res) : null
		} catch (error: any) {
			this.handleError(error, method);
		}
	}

	/**
	 * Delete a user (owner or ADMIN authorized. only owner atm)
	 * Smart contract transaction
	 *
	 * @param {String} username The username of user to delete
	 * USERNAME IS USED ONLY FOR ADMIN ACCESS.
	 * THE USERNAME AT THE CHAINCODE LEVEL IS OBTAINED FROM
	 * THE CALLER'S CERTIFICATE
	 */
	async deleteUser(username: string) {
		const method = 'deleteUser';

		try {
			const transaction = Transaction.user.delete(username)
			return await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
		} catch (error: any) {
			this.handleError(error, method);
		}
	}

	/**
	 * Query all users
	 *
	 * @returns {Object} Array of user objects
	 */
	async getAll(): Promise<Array<IUser>> {
		const method = 'getUsers';

		try {
			const transaction = Transaction.user.getAll()
			const res = await this.contract.evaluateTransaction(transaction.name);
			return (res?.length ? bufferToJson(res) : [])
		} catch (error: any) {
			this.handleError(error, method);
		}
	}
}

export default UserContract

