/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file Replication of ledger via events on a MongoDB implementation
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'MongoDB';

/* Dependencies */
import {MongoClient} from 'mongodb';
import * as mongodb from 'mongodb';
require('dotenv').config();

/* Local */
import { sleep, prettyJSON, Queue, IsJsonString, getLogger } from './libUtil';
import { Product, User, Agreement } from './interfaces'

/* DB Collection names */
const userCol = 'user';
const productCol = 'product';
const inventoryCol = 'inventory';
const agreementCol = 'agreement';

/* All contract events */
let userEvents = ['CreateUser', 'UpdateUser', 'DeleteUser'];
let productEvents = ['CreateProduct', 'UpdateProduct', 'DeleteProduct'];
let agreementEvents = ['NewAgreement', 'NewAgreementAnalytics', 'UpdateAgreement'];

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc
 * 
 * @class
 */
export class OffchainDB {

	private mongoClient: MongoClient;
	private keys: Array<Queue>;
	private connect: any;
	private db: any;
	
	url: string;
	dbName: string;

	/**
	 * Construct an OffchainDB Object
	 * 
	 * @param {String} url The url to establish connection to the Database
	 * @param {String} dbName The name of the database
	 */
	constructor() {
		this.url = process.env.MONGO_URL!;
		this.dbName = process.env.DB_NAME!;
	
		/* Initialization */// @ts-ignore
		this.mongoClient = new MongoClient(this.url, {useUnifiedTopology: true, 
			serializeFunctions:true}); 
		this.keys = [];
	}

	/**
	 * Handle error logging
	 * @ignore
	 */
	private handleError(method: string, e: any): never {
		logger.error('%s - ', method, e);
		throw e;
	}

	/**
	 * Wait for mutex unlock
	 * on specific key
	 *
	 * @ignore
	 * @param {String} key The key to wait for unlock
	 * @param {Number} order The order of key in the queue
	 */
	private async waitOnKey(key: string, order: number) {

		while(this.keys[key].front() !== order &&
			(this.keys[key].front() !== -1)) {
			await sleep(0.1);
		}
	}

	/**
	 * Initialize the DB
	 *
	 */
	async initDB() {
		const method = 'initDB';
		logger.start(method);

		try {
			await this.openConnection();
			await sleep(3000);

			let exists = await this.dbExists();
			if (exists) {
				logger.info('%s - DB already initialized', method);
				await this.closeConnection();
				return;
			}

			await this.db.createCollection(userCol, function(err: any, res: any) {
				if (err) {throw err;}
			});
			await this.db.createCollection(productCol, function(err: any, res: any) {
				if (err) {throw err;}
			});

			await this.db.collection(userCol).createIndex({ _id : 1 });
			await this.db.collection(productCol).createIndex({ _id : 1 });

			logger.info('%s - DB initialized', method);
			await this.closeConnection();
		} catch(e: any) {
			this.handleError(method, e);
		}
	}
	
	/**
	 * Open connection to DB
	 *
	 */
	async openConnection(): Promise<void> {
		const method = 'openConnection';
		logger.info('%s - Opening connection to ', method, this.url);

		try {
			this.connect = await this.mongoClient.connect();
			this.db = this.connect.db(this.dbName);
		} catch(e: any) {
			this.handleError(method, e);
		}

	}

	/**
	 * Close connection to DB
	 *
	 */
	closeConnection(): void {
		const method = 'closeConnection';
		logger.info('%s - Closing connection...', method);

		try {
			this.connect.close();
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Updates the inventory of the user
	 *
	 * @param {String} owner The Owner's ID
	 * @param {String} productID The product's ID
	 * @param {String} key The owner's ID as key
	 * @param {String} op The operation (add/remove)
	 */
	private async updateInventory(owner: string, productID: string, key: string, op: string): Promise<void> {
		const method = 'updateInventory';
		// logger.start(method);

		try {
			let doc: mongodb.Document = { _id : productID, owner : owner };

			// Add Product to Inventory
			if (op === 'add') {
				await this.db.collection(inventoryCol).insertOne(doc, (err: any, res: any) => {
					if (err) {throw err;}
					logger.debug('%s - Owner %s Inventory inserted: %s', method, owner, productID);
					this.keys[key].pop(); // Release lock
				});
			}
			// Remove Product from Inventory
			else if (op === 'remove') {
				await this.db.collection(inventoryCol).deleteOne(doc, (err: any, res: any) => {
					if (err) {throw err;}
					logger.debug('%s - Owner %s Inventory removed: %s', method, owner, productID);
					this.keys[key].pop(); // Release lock
				});
			}
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Write user in DB
	 *
	 * @param {User} data The user's data
	 * @param {String} key The user's username
	 */
	private async writeUser(data: User, key: string): Promise<void> {
		const method = 'writeUser';
		// logger.start(method);

		try {
			// Doc
			data._id = data.username;
			let doc: mongodb.Document = data;

			await this.db.collection(userCol).insertOne(doc, (err: any, res: any) => {
				if (err) {throw err;}
				logger.info('%s - Created User: %s', method, data._id);
				this.keys[key].pop(); // Release lock
			});
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Update user in DB
	 *
	 * @param {User} data The user's data
	 * @param {String} key The user's username
	 */
	private async updateUser(data: User, key: string) {
		const method = 'updateUser';
		// logger.start(method);

		try {
			// Doc
			data._id = data.username;
			let filter: mongodb.Document = { _id: data._id };
			let doc: mongodb.Document = data;

			await this.db.collection(userCol).replaceOne(filter, data,
				(err: any, res: any) => {
					if (err) {throw err;}
					logger.info('%s - User updated: %s', method, data._id);
					this.keys[key].pop(); // Release lock
				});
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Delete user in DB
	 *
	 * @param {User} data The user's data
	 * @param {String} key The user's username
	 */
	private async deleteUser(data: User, key: string) {
		const method = 'deleteUser';
		// logger.start(method);

		let filter: mongodb.Document = { owner : data.username };
		try {
			// Delete all products by owner
			const delPromise_1 = await this.db.collection(productCol).deleteMany(filter,
				(err: any, res: any) => {
				if (err) {throw err;}
				logger.info('%s - Deleted Products of %s', method, data.username);
			})

			// Delete Inventory
			const delPromise_2 = await this.db.collection(inventoryCol).deleteMany(filter,
				(err: any, res: any) => {
				if (err) {throw err;}
				logger.info('%s - Deleted Inventory of %s', method, data.username);
			})

			// Delete user
			filter = { _id : data.username };
			const delPromise_3 = await this.db.collection(userCol).deleteOne(filter,
				(err: any, res: any) => {
				if (err) {throw err;}
				logger.info('%s - Deleted User: %s', method, data.username);
			})

			// Wait for all promises to resolve
			Promise.all([delPromise_1, delPromise_2, delPromise_3]).then(() => {
				this.keys[key].pop() // Release lock
			}).catch((e) => {
				logger.error('%s - Error on Deleting User: %s', method, data.username)
				this.handleError(method, e);
			})
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Write product in DB
	 *
	 * @param {Product} data The product's data
	 * @param {String} key The product's owner
	 */
	private async writeProduct(data: Product, key: string) {
		const method = 'writeProduct';
		// logger.start(method);

		try {
			data._id = data.id;
			let doc: mongodb.Document = data;

			await this.db.collection(productCol).insertOne(doc, async(err: any, res: any) => {
				if (err) {throw err;}
				
				// Add product to Inventory
				await this.updateInventory(data.owner, data.id, key, 'add')
				logger.info('%s - Created Product: %s', method, data.id);
				// LOCK IS RELEASED AFTER updateInventory METHOD
			});
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Update product in DB
	 *
	 * @param {Product} data The product's data
	 * @param {String} key The product's owner
	 */
	private async updateProduct(data: Product, key: string) {
		const method = 'updateProduct';
		// logger.start(method);

		try {
			data._id = data.id;
			let filter: mongodb.Document = { _id: data._id };
			let doc: mongodb.Document = data;

			await this.db.collection(productCol).replaceOne({_id : data._id}, data,
				(err: any, res: any) => {
					if (err) {throw err;}
					logger.info('%s - Updated Product: %s', method, data._id);
					this.keys[key].pop(); // Release Lock
				});
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Delete a product in DB
	 *
	 * @param {Product} data The product's data
	 * @param {String} key The product's owner
	 */
	private async deleteProduct(data: Product, key: string) {
		const method = 'deleteProduct';
		// logger.start(method);

		try {
			data._id = data.id;
			let filter: mongodb.Document = { _id: data._id };

			await this.db.collection(productCol).deleteOne(filter, async (err: any, res: any) => {
				if (err) {throw err;}

				// Remove Product from Inventory
				await this.updateInventory(data.owner, data.id, key, 'remove');
				logger.info('%s - Deleted Product: %s', method, data.id);
				// LOCK IS RELEASED ON updateInventory METHOD
			});
		} catch(e: any) {
			this.handleError(method, e);
		}
	}

	/**
	 * Write an agreement in DB
	 *
	 * @param {Agreement} data The agreement's data to insert
	 * @param {String} key The txID of the agreement
	 */
	private async writeAgreement(data: Agreement, key: string) {
		const method = 'writeAgreement';
		// logger.start(method);

		try {
			data._id = data.txID;
			let doc: mongodb.Document = data;
			
			await this.db.collection(agreementCol).insertOne(doc, (err: any, res: any) => {
				if (err) {throw err;}
				logger.info('%s - Created Agreement: %s', method, data._id);
				this.keys[key].pop(); // Release Lock
			});
		} catch(e: any) {
			this.handleError(method, e);
		}

	}

	/**
	 * Update an agremeent in DB
	 *
	 * @param {Object} data The new data
	 * @param {String} key The txID of the agreement
	 */
	private async updateAgreement(data: any, key: string) {
		const method = 'updateAgreement';
		logger.start(method);

		try {
			data._id = data.txID;
			let filter: mongodb.Document = { _id: data.txID };
			let doc: mongodb.Document = data;

			await this.db.collection(agreementCol).replaceOne(filter, doc, (err: any, res: any) => {
				if (err) {throw err;}
				logger.info('%s - Updated Agreement: %s Status: %s', method, data.txID, data.status);
				this.keys[key].pop(); // Release Lock
			});
		} catch(e: any) {
			this.handleError(method, e);
		}

	}

	/**
	 * Query All Users
	 *
	 * @returns {Object[]} Returns all users
	 */
	async readUsers(): Promise<Array<User>> {
		const method = 'readUsers';
		logger.start(method);

		try {
			return await this.db.collection(userCol).find({}).toArray();
		} catch(e: any) {
			return this.handleError(method, e);
		}
	}

	/**
	 * Query User
	 *
	 * @param {String} userID The user's ID
	 * @returns {Object} Returns a User's data
	 */
	async readUserData(userID: string): Promise<User> {
		const method = 'readUserData';
		// logger.start(method);

		try {
			return await this.db.collection(userCol).findOne({_id : userID});
		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	/**
	 * Query All Products
	 *
	 * @returns {Object[]} Returns all products
	 */
	async readProducts(): Promise<Array<Product>> {
		const method = 'readProducts';
		// logger.start(method);

		try {
			return await this.db.collection(productCol).find({}).toArray();
		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	/**
	 * Fetch all products from database
	 * joined with the owner's certificate expiration date
	 *
	 * @returns {Array} Array of products with the expiration date
	 */
	async readCatalogue(): Promise<Array<Product>> {
		const method = 'readCatalogue';
		logger.start(method);

		try {
			return await this.db.collection(productCol).aggregate([
				{
					$lookup: {
						from: userCol,
						localField: 'owner',
						foreignField: '_id',
						as: 'seller'
					}
				},
				{
					$unwind: '$seller'
				},
				{
					$project: {
						// owner: 0,
						_id: 0,
						// validTo: '$seller.validTo',
						'seller.type': 0,
						'seller.org': 0,
						// "seller.seller": '$seller.username',
						'seller.isOrg': 0,
						'seller.isBuyer': 0,
						'seller.purposes': 0,
						'seller.username': 0,
						'seller.id': 0,
						'seller._id': 0
					}
				}
			]).toArray();
		} catch(e: any) {
			throw this.handleError(method, e);
			// return null;
		}
	}

	/**
	 * Query All Products by filter
	 *
	 * @param {Object} filter The filter to apply to the query statement
	 * @returns {Object[]} Returns all Product objects in DB by filter
	 */
	 // TODO
	async readProductsByFilter(filter: any): Promise<Array<Product>> {
		const method = 'readProductsByFilter';
		// logger.start(method);

		try {
			return await this.db.collection(productCol).find(filter).toArray();
		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	/**
	 * Query All Products by filter
	 *
	 * @returns {Object[]} Returns all agreements
	 */
	async readAgreements(): Promise<Array<Agreement>> {
		const method = 'readAgreements';
		// logger.start(method);

		try {
			return await this.db.collection(agreementCol).find({}).toArray();
		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	/**
	 * Query Product
	 *
	 * @param {String} agreementID The agreement's ID
	 * @returns {Agreement} Returns an Agreement's data
	 */
	async readAgreementData(agreementID: string): Promise<Agreement> {
		const method = 'readAgreementData'
		// logger.start(method)

		try {
			return await this.db.collection(agreementCol).findOne({_id : agreementID});

		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	/**
	 * Query Product
	 *
	 * @param {String} productID The product's ID
	 * @returns {Product} Returns a Product's data
	 */
	 // todo
	async readProductData(productID: string): Promise<Product> {
		const method = 'readProductData';
		// logger.start(method);

		try {
			return await this.db.collection(productCol).findOne({_id : productID});

		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	// tdo
	async readTransactionsByFilter(filter: any): Promise<Array<Agreement>> {
		const method = 'readTransactionsByFilter';

		try {
			return await this.db.collection(agreementCol).find(filter).toArray();
		} catch(e: any) {
			return this.handleError(method, e);
			// return null;
		}
	}

	
	/**
	 * Reconstruct DB from peer's World State Index
	 *
	 */
	// async reconstructFromLedger() {
	// 	// TODO: call GetAllUsers, GetAllProducts
	// 	// and call eventHandler
	// }

	/**
	 * Handle events and DB operations
	 *
	 * @param {String} eventName The name of the event from the smart contract
	 * @param {Object} eventData Contains the data of the event
	 */
	async eventHandler(eventName: string, eventData: any): Promise<void> {
		const method = 'eventHandler';
		// logger.start(method);

		// event data
		let data;

		// key of documents
		let key;

		// queue order
		let order;

		try {

			/* Set key of Object
				User: username
				Product: owner
				Agreement: txID
			*/
			if (userEvents.indexOf(eventName) > -1) {
				if (IsJsonString(eventData)) {
					data = prettyJSON(eventData);
					key = data.username;
				} else {
					data = eventData.toString();
					logger.debug('%s - ', method, data);
					key = data;
				}
			}
			else if (productEvents.indexOf(eventName) > -1) {
				if (IsJsonString(eventData)) {
					data = prettyJSON(eventData);
					key = data.owner;
				} else {
					data = eventData.toString();
					logger.debug('%s - ', method, data);
					key = data;
				}

			}
			else if (agreementEvents.indexOf(eventName) > -1) {
				if (IsJsonString(eventData)) {
					data = prettyJSON(eventData);
					key = data.txID;
				} else {
					data = eventData.toString();
					logger.debug('%s - ', method, data);
					key = data;
				}
			}
			else {
				logger.warn('%s - Unhandled event', method, eventName)
				return
				// throw new Error('Unhandled event');
			}

			// Lock key if its being processed by other operation
			if (Object.getOwnPropertyDescriptor(this.keys, key)) {
				order = this.keys[key].push();
				await this.waitOnKey(key, order);
				logger.debug('%s - Starting... %s ', method, eventName + ' Order: ' + order);

			} else {
				this.keys[key] = new Queue();
				order = 0;
				// logger.debug('%s - ', method, eventName + ' Order: ' + order);
				this.keys[key].push();
			}

			// Event routing
			switch (eventName) {
			case 'CreateUser':
				await this.writeUser(data, key);
				break;
			case 'UpdateUser':
				await this.updateUser(data, key);
				break;
			case 'DeleteUser':
				await this.deleteUser(data, key);
				break;
			case 'CreateProduct':
				await this.writeProduct(data, key);
				break;
			case 'UpdateProduct':
				await this.updateProduct(data, key);
				break;
			case 'DeleteProduct':
				await this.deleteProduct(data, key);
				break;
			case 'NewAgreement':
			case 'NewAgreementAnalytics':
				await this.writeAgreement(data, key);
				break;
			case 'UpdateAgreement':
				await this.updateAgreement(data, key);
				break;
			default:
				break;
			}
			logger.debug('%s - Releasing... %s ', method, eventName + ' Order: ' + order);

		} catch(e: any) {
			return this.handleError(method, e);
		}

	}

	/**
	 * Check if DB exists
	 *
	 * @returns {bool} True if exists, false if not
	 */
	async dbExists(): Promise<boolean> {
		const method = 'dbExists';
		logger.start(method);

		try {
			// this.connect = await this.mongoClient.connect();
			const dbAdmin = this.connect.db(this.dbName).admin();
			const dbs = await dbAdmin.listDatabases();

			for (const database of dbs.databases) {
				logger.debug('%s - name: %s ', method, database.name);
				if (database.name === this.dbName) {
					return true;
				}
			}

			return false;
		} catch(e: any) {
			this.handleError(method, e);
			return false;
		}
	}

	/*
	 * Delete the Database
	 */
	async dropDatabase() {
		await this.openConnection();
		await this.db.dropDatabase((err: any) => {
			if (err) {
				logger.error('Error : '+err);
				throw err;
			}
			logger.info('Deleted DB successfully');
			// after all the operations with db, close it.
			this.connect.close();
		});
	}

}

