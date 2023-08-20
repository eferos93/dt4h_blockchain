/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file A library implementing the API for the chaincode smart contract Data Catalogue
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'DataContract';

/* Dependencies */
import {
	connectGateway,
	prettyJSONString,
	prettyJSON,
	getLogger,
	bufferToJson
} from './libUtil';
import { IProduct, BuyerParameters } from './interfaces';
import { Contract } from '@hyperledger/fabric-gateway';
import Transaction from './Transactions'

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc API for the Data Catalogue contract 
 * 
 * @class
 */
export class DataContract {

	// channelID: string;
	// chaincodeID: string;
	contract: Contract;
	
	constructor(contract: Contract) {
		this.contract = contract
		// this.channelID = channelID
		// this.chaincodeID = chaincodeID
	}

	/**
	 * Logs an error message and rethrows the error.
	 * 
	 * @param error The error that was caught
	 * @param method The name of the method where the error occurred
	 * @throws {Error}
	 */
	handleError(error: Error, method: string): never {
		// console.log(error)
		logger.error(`${method} - ${error}`);
		throw error;
	}

	/**
	 * Submit CreateProduct transaction
	 * Create a product
	 *
	 * @param {IProduct} product The product object
	 * @returns {Promise<string>} productID on success, else error
	 */
	async createProduct(product: IProduct): Promise<any> {
		const method = 'createProduct';

		try {
			const transaction = Transaction.product.create(product)
			let res = await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
			return Buffer.from(res).toString('utf-8');
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Submit UpdateProduct Transaction
	 * Updates an existing product
	 *
	 * @param {IProduct} product The product object
	 * @returns {Promise<any>} null on success, else error
	 */
	async updateProduct(product: IProduct): Promise<any> {
		const method = 'updateProduct';

		try {
			const transaction = Transaction.product.update(product)
			let res = await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
			return Buffer.from(res).toString('utf-8');
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Evaluate ReadProduct Transaction
	 * Fetch a product from ledger
	 *
	 * @param {string} productID The productID (hash)
	 * @returns {Promise<IProduct>} IProduct if exists
	 */
	async readProduct(productID: string): Promise<IProduct> {
		const method = 'readProduct';

		try {
			const transaction = Transaction.product.read(productID)
			const res = await this.contract.evaluateTransaction(transaction.name, ...transaction.options!.arguments);
			return res?.length ? bufferToJson(res) : null
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Submit BuyProduct Transaction
	 * Buy a product as a buyer user
	 *
	 * @param {string} productID The productID (hash)
	 * @param {BuyerParameters} buyerParams The buyer parameters
	 * @returns {Promise<string>} TransactionID on success, else error
	 */
	async buyProduct(productID: string, buyerParams: BuyerParameters): Promise<string> {
		const method = 'buyProduct';

		try {
			const transaction = Transaction.product.buy(productID, buyerParams)
			const res = await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
			return Buffer.from(res).toString('utf-8');
		} catch(e: any) {
			this.handleError(e, method);
		}
	}


	/**
	 * Submit DeleteProduct Transaction
	 * Delete a product (Delete a State)
	 *
	 * @param {string} productID The productID (hash)
	 */
	async deleteProduct(productID: string): Promise<any> {
		const method = 'deleteProduct';

		try {
			const transaction = Transaction.product.delete(productID)
			return await this.contract.submitTransaction(transaction.name, ...transaction.options!.arguments);
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Query All Products
	 *
	 * @returns {Promise<any[]>} An array of all products
	 */
	async getAll(): Promise<any[]> {
		const method = 'getProducts';

		try {
			const transaction = Transaction.product.getAll()
			const res = await this.contract.evaluateTransaction(transaction.name);
			return res?.length ? bufferToJson(res) : null
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Query History of product
	 *
	 * @param {string} productID The productID (hash)
	 * @returns {Promise<any[]>} An array of all product's history
	 */
	async getHistory(productID: string): Promise<any[]> {
		const method = 'getHistory';

		try {
			const transaction = Transaction.product.getHistory(productID)
			const res = await this.contract.evaluateTransaction(transaction.name, ...transaction.options!.arguments);
			return res?.length ? bufferToJson(res) : null
		} catch(e: any) {
			this.handleError(e, method);
		}

	}
}

export default DataContract