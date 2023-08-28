/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file Replication of ledger via events on a MongoDB implementation
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'MongoDB';

/* Dependencies */
const mongoose = require('mongoose')
require('dotenv').config();

/* Local */
import { sleep, prettyJSON, IsJsonString, getLogger } from './libUtil';
import { IProduct, IUser, IAgreement, IInventory } from './interfaces'
import * as fields from './queryFields' 
import { DATABASE } from './Config'
import { ProductModel, UserModel, AgreementModel, InventoryModel } from './models'

/* All contract events */
let userEvents = ['CreateUser', 'UpdateUser', 'DeleteUser'];
let productEvents = ['CreateProduct', 'UpdateProduct', 'DeleteProduct'];
let agreementEvents = ['NewAgreement', 'NewAgreementAnalytics', 'UpdateAgreement'];
let allEvents = [...userEvents, ...productEvents, ...agreementEvents]

class User {

	col: typeof UserModel;
	inventories: Inventory;
	products: Product;
	PAGE_SIZE: number;

	constructor() {
		this.col = UserModel
		this.inventories = new Inventory()
		this.products = new Product()
		this.PAGE_SIZE = 10
	}

	async insert(obj: IUser) {
		obj._id = obj.username;
		return await this.col.create(obj)
	}

	async update(obj: IUser) {
		return await this.col.updateOne({_id: obj.username}, obj)
	}

	async delete(id: string) {
		await this.products.deleteByOwner(id)
		await this.col.deleteById(id)
		return await this.inventories.deleteByOwner(id)
	}

	async get(query: object) {
		return await this.col.find(query).select("-__v")
	}

	async getByUsername(query: string) {
		return await this.col.findOne({ username: query }).select("-__v")
	}

	async getAll(query={}, fields={}) {
		return await this.col.find(query, fields).select("-__v")
	}

	async getPagination(query={}, fields={}, select='', page=1,
	 limit=this.PAGE_SIZE, sortBy: {[key: string]: 1 | -1} = {timestamp: -1}) {
		 return await this.col
		 .find(query, fields)
		 .select(select)
		 //@ts-ignore
		.sort(sortBy) 
		.limit(limit)
		.skip((page-1) * limit)
	}

	async getById(id: string) {
		return await this.col.findById(id)
	}

}


class Product {

	inventories: Inventory;
	col: typeof ProductModel;
	PAGE_SIZE: number;

	constructor() {
		this.col = ProductModel
		this.inventories = new Inventory()
		this.PAGE_SIZE = 10
	}

	async insert(obj: IProduct) {
		obj._id = obj.id;
		await this.col.create(obj)
		let inv = {productID: obj.id, owner: obj.owner}
		return await this.inventories.insert(inv)
	}

	async update(obj: IProduct) {
		return await this.col.updateOne({_id: obj.id}, obj)
	}

	async delete(id: string) {
		await this.col.deleteById(id)
		return await this.inventories.deleteByProduct(id)
	}

	async deleteByOwner(id: string) {
		return await this.col.deleteOne({owner: id})
	}

	async get(query: object, fields={}) {
		return await this.col.find(query, fields)
	}

	async getById(id: string, fields={}) {
		return await this.col.findById(id, fields)
	}

	async getAll(query={}, fields={}) {
		return await this.col.find(query, fields).select("-__v")
	}


	async getPagination(query={}, fields={}, select={}, populSelect={}, page=1,
	 limit=this.PAGE_SIZE, sortBy: {[key: string]: 1 | -1} = {timestamp: -1}) {
		return await this.col
		.find(query, fields)
		.select(select)
		.populate({ 
			path: 'owner', 
			model: UserModel,
			select: populSelect
		})
		.sort(sortBy)
		.limit(limit)
		.skip((page-1) * limit)
	}

	async getByOwner(id: string) {
		return await this.col.find({owner: id})
	}


}


class Agreement {

	col: typeof AgreementModel;

	constructor() {
		this.col = AgreementModel
	}

	async insert(obj: IAgreement) {
		obj._id = obj.txID;
		return await this.col.create(obj)
	}

	async update(obj: IAgreement) {
		return await this.col.updateOne({_id: obj.txID}, obj)
	}

	async delete(id: string) {
		return await this.col.deleteById(id)
	}

	async get(query: object) {
		return await this.col.find(query)
	}

	// TODO: use lean?
	async getById(id: string) {
		return await this.col.findById(id)
	}

	async getAll() {
		return await this.col.find()
	}
	
	async getPagination(query={}, fields={}, select='', page=1,
	 limit=500, sortBy: {[key: string]: 1 | -1} = {timestamp: -1}) {
		return await this.col
		.find(query, fields)
		.select(select)
		.sort(sortBy)
		.limit(limit)
		.skip((page-1) * limit)
	}
}


class Inventory {

	col: typeof InventoryModel;

	constructor() {
		this.col = InventoryModel
	}

	async insert(obj: IInventory) {
		obj._id = obj.productID
		return await this.col.create(obj)
	}

	// async update(obj: Inventory) {
	// 	return await this.col.updateOne(obj)
	// }

	async deleteByProduct(id: string) {
		return await this.col.deleteOne({_id: id})
	}

	async deleteByOwner(id: string) {
		return await this.col.deleteOne({owner: id})
	}

	// TODO: use lean?
	async getByOwner(id: string) {
		return await this.col.findOne({owner: id})
	}

}

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc
 * 
 * @class
 */
export class OffchainDB {

	users: User;
	products: Product;
	agreements: Agreement;
	inventories: Inventory;

	url: string;
	dbName: string;
	connection: any;

	/**
	 * Construct an OffchainDB Object
	 * 
	 */
	constructor() {
		this.url = DATABASE.url;
		this.dbName = DATABASE.name;

		this.users = new User()
		this.products = new Product()
		this.agreements = new Agreement()
		this.inventories = new Inventory()
	}

	/**
	 * Handle error logging
	 * @ignore
	 */
	handleError(method: string, e: any): never {
		logger.error(`${method} - ${e}`);
		throw e;
	}


	/**
	 * Initialize the DB
	 *
	 */
	async connect() {
		const method = 'init';
		try {
			logger.info(`${method} - Connecting to : ${this.url}...`)
			this.connection = (await mongoose.connect(this.url)).connection
			return this.connection
		} catch(e: any) {
			this.handleError(method, e);
		}
	}


	/**
	 * Close connection to DB
	 *
	 */
	async disconnect(): Promise<void> {
		const method = 'disconnect';
		logger.info(`${method} - Closing connection...`);

		try {
			return await this.connection.close();
		} catch(e: any) {
			this.handleError(method, e);
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
	async eventHandler(eventName: string, eventData: any): Promise<any> {
		const method = 'eventHandler';

		let data: any = eventData;

		try {

			// Check if event exists and parse data
			if (!(allEvents.indexOf(eventName) > -1)) {
				logger.warn(`${method} - ${eventName}`)
				return
			}

			// Event routing
			switch (eventName) {
				case 'CreateUser':
					return await this.users.insert(data);
				case 'UpdateUser':
					return await this.users.update(data);
				case 'DeleteUser':
					return await this.users.delete(data.username);
				case 'CreateProduct':
					return await this.products.insert(data);
				case 'UpdateProduct':
					return await this.products.update(data);
				case 'DeleteProduct':
					return await this.products.delete(data.id);
				case 'NewAgreement':
				case 'NewAgreementAnalytics':
					return await this.agreements.insert(data);
				case 'UpdateAgreement':
					return await this.agreements.update(data);
				default:
					break;
			}

		} catch(e: any) {
			return this.handleError(method, e);
		}

	}

	/**
	 * Drop Database
	 * 
	 */
	async drop(): Promise<void> {
		const method = 'drop'
		logger.info(`${method} - Dropping database... ${this.url}`)
		return await this.connection.db.dropDatabase()
	}
}

export default OffchainDB

