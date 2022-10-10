/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file A library implementing the API for the chaincode smart contract Data Catalogue
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'DataContract';

/* Dependencies */
import { connectGateway, prettyJSONString, prettyJSON, getLogger } from './libUtil'
import { sendTransaction } from './libSignOffline';
import { Product, BuyerParameters } from './interfaces';

/* Constants */
const dataContract = 'DataContract';
const createProductTx = 'CreateProduct';
const readProductTx = 'ReadProduct';
const updateProductTx = 'UpdateProduct';
const deleteProductTx = 'DeleteProduct';
const buyProductTx = 'BuyProduct';
const getAllProductsTx = 'GetAllProducts';

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc API for the Data Catalogue contract 
 * 
 * @class
 */
export class DataContract {

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
		this.chaincodeID = chaincodeID
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
		return e;
	}

	/**
	 * Submit CreateProduct transaction
	 * Create a product
	 *
	 * @param {String} userID  The user's ID
	 * @param {Object} Product The product object
	 * @returns {String} productID on success, else error
	 */
	async createProduct(userID: string, Product: Product) {
		const method = 'createProduct';
		logger.start(method);

		let res = null;
		// let gateway;

		try {
			// gateway = await connectGateway(userID);
			// const network = await gateway.getNetwork(this.channelID);
			// const contract = network.getContract(this.chaincodeID, dataContract);

			const transaction = {fcn: dataContract + ':' + createProductTx, args: [prettyJSONString(Product)]};
			res = await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);
			logger.debug('%s - transaction response: %s', method, res);

			// res = await contract.submitTransaction(createProductTx, prettyJSONString(Product));
			// res = res.toString();
		} catch(e: any) {
			res = this.handleError(e, method);
		}

		// if(gateway) {gateway.disconnect();}

		return res;
	}

	/**
	 * Submit UpdateProduct Transaction
	 * Updates an existing product
	 *
	 * @param {String} userID  The user's ID
	 * @param {Object} Product The product object
	 * @returns {Error} null on success, else error
	 */
	async updateProduct(userID: string, Product: Product) {
		const method = 'updateProduct';
		logger.start(method);

		let res = null;

		try {

			const transaction = {fcn: dataContract + ':' + updateProductTx, args: [prettyJSONString(Product)]};
			res = await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);

		} catch(e: any) {
			res = this.handleError(e, method);
		}

		return res;
	}

	/**
	 * Evaluate ReadProduct Transaction
	 * Fetch a product from ledger
	 *
	 * @param {String} userID
	 * @param {String} productID The productID (hash)
	 * @returns {Object} Product if exists
	 */
	async readProduct(userID: string, productID: string): Promise<Product> {
		const method = 'readProduct';
		logger.start(method);

		let res = null;
		let gateway;

		try {
			gateway = await connectGateway(userID);
			const network = await gateway.getNetwork(this.channelID);
			const contract = network.getContract(this.chaincodeID, dataContract);

			// const transaction = {fcn: dataContract + ':' + readProductTx, args: [productID]};
			// logger.debug(transaction);
			// res = await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);
			logger.debug('%s - %s', method, productID);
			res = await contract.evaluateTransaction(readProductTx, productID);
			res = prettyJSON(res);
			logger.debug('%s - Read result: %j', method, res);

		} catch(e: any) {
			res = this.handleError(e, method);
		}

		if(gateway) {gateway.disconnect();}

		return res;
	}

	/**
	 * Submit BuyProduct Transaction
	 * Buy a product as a buyer user
	 *
	 * @param {String} userID
	 * @param {String} productID The productID (hash)
	 * @param {Array} buyerParams The buyer parameters
	 * @returns {String} TransactionID on success, else error
	 */
	async buyProduct(userID: string, productID: string, buyerParams: BuyerParameters) {
		const method = 'buyProduct';
		logger.start(method);

		let res = null;

		try {

			const transaction = {fcn: dataContract + ':' + buyProductTx, args: [productID, prettyJSONString(buyerParams)]};
			logger.debug('%s - ', method, transaction);
			res = await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);
			logger.debug('%s - Result: ', method, res);

		} catch(e) {
			res = this.handleError(e, method);
		}

		return res;
	}

	/**
	 * Submit DeleteProduct Transaction
	 * Delete a product (Delete a State)
	 *
	 * @param {String} userID
	 * @param {String} productID The productID (hash)
	 * @returns {Error} null on success, else error
	 */
	async deleteProduct(userID: string, productID: string) {
		const method = 'deleteProduct';
		logger.start(method);

		let res = null;

		try {

			const transaction = {fcn: dataContract + ':' + deleteProductTx, args: [productID]};
			logger.debug('%s - %s', method, transaction);
			await sendTransaction(userID, transaction, this.channelID, this.chaincodeID);

		} catch(e: any) {
			res = this.handleError(e, method);
		}

		return res;
	}

	/**
	 * Query All Products
	 *
	 * @param {String} clientID The client's ID
	 * @returns {Array} An array of all products
	 */
	async getProducts(clientID: string): Promise<any> {
		const method = 'getProducts';
		logger.start(method);

		let res: any;
		let gateway;

		try {
			gateway = await connectGateway(clientID);
			const network = await gateway.getNetwork(this.channelID);
			const contract = network.getContract(this.chaincodeID, dataContract);

			res = await contract.evaluateTransaction(getAllProductsTx);
			res = prettyJSON(res);
			if (!res) {res = [];}
		} catch(e: any) {
			res = this.handleError(e, method);
		}

		if(gateway) {gateway.disconnect();}

		return res;
	}

}

