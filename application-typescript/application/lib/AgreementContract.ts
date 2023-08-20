/**
 * Copyright Lynkeus 2021. All Rights Reserved.
 *
 * @file A library implementing the API for the smart contract IAgreement
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'AgreementContract';

/* Dependencies */
import { getLogger, bufferToJson } from './libUtil';
import { IAgreement, AgreementStatus } from './interfaces';
import { Contract } from '@hyperledger/fabric-gateway';
import Transaction from './Transactions'

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc API for the IAgreement contract 
 * 
 * @class
 */
export class AgreementContract {

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
		console.log(error)
		logger.error(`${method} - ${error.message}`);
		throw error;
	}

	/**
	 * Update an agreement (Org Client only)
	 *
	 * @param {String} transactionID The tx/agreement's ID
	 * @param {String} status The new status to update (Paid/Access)
	 * @returns {String} null on success, error on failure
	 */
	async updateAgreement(transactionID: string, status: AgreementStatus): Promise<string> {
		const method = 'updateAgreement';

		try {
			const transaction = Transaction.agreement.update(transactionID, status)
			const res = await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
			return Buffer.from(res).toString('utf-8');
		} catch(e: any) {
			return this.handleError(e, method);
		}
	}

	/**
	 * Fetch an agreement
	 * @param {String} transactionID The agreement's ID
	 * @returns {Object} The agreement if found
	 */
	async readAgreement(transactionID: string): Promise<IAgreement> {
		const method = 'getAgreement';

		try {
			const transaction = Transaction.agreement.read(transactionID)
			const res = await this.contract.evaluateTransaction(transaction.name, ...transaction.options!.arguments);
			return res?.length ? bufferToJson(res) : null
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Get All agreements
	 * @returns {IAgreement[]} Array of agreements
	 */
	async getAgreements(): Promise<Array<IAgreement>> {
		const method = 'getAgreements';

		try {
			const transaction = Transaction.agreement.getAll()
			const res = await this.contract.evaluateTransaction(transaction.name, ...transaction.options!.arguments);
			return res?.length ? bufferToJson(res) : null
		} catch(e: any) {
			this.handleError(e, method);
		}
	}
}

export default AgreementContract