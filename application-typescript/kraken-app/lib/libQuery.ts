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
	 * joined with the owner's data
	 *
	 * @returns {Array} Array of products populated with owner
	 */
	async getCatalogue(userID: string, query={}, page=1, limit=500) {
		const method = 'getCatalogue';
		logger.start(method);
		

		return await this.products.col.find(query, limit)
			.populate({ path: 'owner', model: UserModel })
			.skip((page-1) * limit)
			.limit(limit)
	}

		// const buyer = await this.users.get(userID);
		// if (!buyer) return filteredData


		// return await this.products.col.aggregate([
		//     {
		//         $lookup: {
		//             from: 'users',
		//             localField: 'owner',
		//             foreignField: '_id',
		//             as: 'seller'
		//         }
		//     },
		//     {
		//         $unwind: '$seller'
		//     },
		//     {
		//     	$match: {
		//     		$and: [
		//         		'policy.purposes': {
		//         			$in: buyer.purposes
		//             	}
		//     		]
		//     	}
		//     },
		//     {
		//         $project: {
		//             // owner: 0,
		//             _id: 0,
		//             // validTo: '$seller.validTo',
		//             // 'seller.type': 0,
		//             // 'seller.org': 0,
		//             // "seller.seller": '$seller.username',
		//             // 'seller.isOrg': 0,
		//             // 'seller.isBuyer': 0,
		//             // 'seller.purposes': 0,
		//             // 'seller.username': 0,
		//             // 'seller.id': 0,
		//             // 'seller._id': 0,
		//             // 'seller.__v': 0,
		//             // 'seller.mspid': 0,
		//             // 'seller.certKey': 0
		//         }
		//     }
		// ])


	// *
	//  * Match purposes buyer to policy
	//  *
	//  * @param {Array<string>} buyerPurpose Buyer's purposes of buying
	//  * @param {Array<string>} dataPurpose  IProduct's policy purposes
	//  * @returns {Boolean} True if purposes match, else false
	 
	matchPurpose(buyerPurpose: Array<string>, dataPurpose: Array<string>): boolean {
		try {
			const result = !_.isEmpty(_.intersection(buyerPurpose, dataPurpose));
			return result;
		} catch (e: any) {
			logger.error(e);
			throw e;
		}
	}

	/**
	 * Filtering algorithm
	 *
	 * @param {String} userID The ID of the user
	 * @returns {IProduct[]} Array of IProduct Objects matched to purposes
	 */
	async queryFilteredProducts(userID: string): Promise<Array<IProduct> | Error> {
		const method = 'queryFilteredProducts';
		logger.start(method);

		let filteredData: any = [];

		try {
			const buyer = await this.users.getByUsername(userID);
			logger.debug('%s - ', method, buyer);

			if (!buyer) return filteredData

			// let query = {    }

			// TODO: filter products with seller's data
			const products = await this.getCatalogue(userID, {}, 1, 5000);
			logger.debug('%s - Total Products Count: ', method, products.length)

			products.forEach((product: any, index: any) => {

				// Exclude owner
				if (product.owner === buyer.username) {
					return;
				}
				// Exclude expired certificates
				else if (new Date(product.seller.validTo).getTime() < (new Date().getTime())) {
					return;
				}
				// Add matched policy products to new array (Non blurred)
				else if (this.matchPurpose(buyer.purposes, product.policy.purposes)) {
					product.matched = true;
				}
				// Add non matched policy products to new array (Blurred)
				else {
					product.matched = false;
				}

				filteredData.push(product);
			});

			logger.debug('%s - Filtered Products Count: ', method, filteredData.length)
			return filteredData;
		} catch (e: any) {
			logger.error('%s - ', method, e);
			throw e;
		}
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

