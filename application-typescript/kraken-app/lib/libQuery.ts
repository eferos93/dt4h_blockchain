/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file API for MongoDB interaction
 * @module libQuery
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'Query';

/* Dependencies */
import * as _ from 'lodash';

/* Local */
import { OffchainDB } from './libReplicateDB';
import { getLogger } from './libUtil';
import { IUser, IProduct, IAgreement } from './interfaces';
import { UserModel } from './models';
import * as fields from './queryFields' 

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc Implementation of queries to the Cache Database
 * 
 * @class
 * */
export class Query extends OffchainDB {


	/**
	 * @constructor
	 */
	constructor() {
		super()
	}


	/**
	 * Fetch all products from database
	 *
	 * @returns {Array} Array of products populated with owner
	 */
	async queryCatalogue(query={}, page=1, limit=500) {
		const method = 'getCatalogue';
		logger.start(method);
		
		return await this.products.col.find(query, limit)
			.populate({ path: 'owner', model: UserModel })
			.skip((page-1) * limit)
			.limit(limit)
	}


	/**
	 * Fetch all products from database
	 * join with buyer's purposes
	 * 
	 * @returns {Array} Array of products populated with owner
	 */
	async queryFilteredCatalogue(userID: string, query={}, page=1, limit=500): Promise<Array<IProduct>> {
		const method = 'queryFilteredCatalogue';
		logger.start(method);
		
		const buyer = await this.users.getByUsername(userID);
		console.log(buyer)
		if (buyer) {
			query = {
				'policy.purposes': {
					$in: buyer.purposes
				}				
			}
		}

		return await this.products.getPagination(query, {},
			fields.getProductSelect(), fields.getSellerSelect(), 
			page, limit, { timestamp: -1 })
	}


	/**
	 * Fetch all users from database
	 *
	 * @returns {Array} Array of users
	 */
	async queryUsers(query={}, page=1, limit=500) {
		const method = 'getCatalogue';
		logger.start(method);
		
		return await this.users.getAll();
	}


	// /**
	//  * Queries the history of transactions for a specific product
	//  * 
	//  * @param {String} productID The product's ID (hash)
	//  * @returns {Array} Array of IAgreement Objects 
	//  * */
	// async queryTransactionHistoryForProduct(productID: string) {
	// 	try {
	// 		const filter = { productID: productID }
	// 		let res = await this.offchainDB.readTransactionsByFilter(filter);

	// 		return res;
	// 	} catch (e: any) {
	// 		logger.error(e);
	// 		throw e;
	// 	}
	// }

}

