/*
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * Author: Alexandros Tragkas
 */

'use strict';

const TYPE = 'MonitorDB';
process.env.APP_LOGGING = '{"debug":"validate_debug.log", "info":"console"}';

/* Require libs */
const { 
	OffchainDB, 
	DataContract, 
	UserContract, 
	AgreementContract, 
	BlockListener } = require('./kraken-app');
const { Util } = require('./kraken-app');
const _ = require('lodash');
const fs = require('fs');

require('dotenv').config();
const url = process.env.DB_LEDGER_URL;
const dbName = process.env.DB_LEDGER;

/* Env */
const client = process.env.CLIENT;
const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;

/* Init */
const userContract = new UserContract(channelID, chaincodeID);
const dataContract = new DataContract(channelID, chaincodeID);
const agreementContract = new AgreementContract(channelID, chaincodeID);
const offchainDB = new OffchainDB(url, dbName);

/* Logging */
const logger = Util.getLogger(TYPE);

/**
 * Validates DB against the blockchain
 *
 * @returns {bool} True if DB-Ledger are synced, else error
 */
async function validateDB() {
	const method = 'validateDB';

	try {

		/* Verify Products */
		let products = await dataContract.getProducts(client);
		let dbprods = await offchainDB.products.getAll();
		logger.debug('%s - Total DB Products: ', method, dbprods.length);
		logger.debug('%s - Total BC Products: ', method, products.length);

		if (dbprods.length !== products.length) {
			throw new Error('Not equal total number of products');
		}

		if (Array.isArray(products) && products.length) {
			for (let i = 0; i < products.length; i++) {
				await offchainDB.products.getById(products[i].id).then((res) => {
					if (!Util.isEqualCommonProperties(products[i], res)) {
						logger.debug('%s - ', method, products[i], res);
						throw new Error(`Not equal product ${res.id}`);
					}
				});
			}
		} else if (dbprods.length > 0) {
			throw new Error('Different number of products');
		}

		/* Verify Users */
		let users = await userContract.getUsers(client);
		let dbusers = await offchainDB.users.getAll();
		logger.debug('%s - Total DB Users: ', method, dbusers.length);
		logger.debug('%s - Total BC Users: ', method, users.length);

		if (dbusers.length !== users.length) {
			throw new Error('Not equal total number of users');
		}

		if (Array.isArray(users) && users.length) {
			for (let i = 0; i < users.length; i++) {
				await offchainDB.users.getByUsername(users[i].username).then((res) => {
					if (!Util.isEqualCommonProperties(users[i], res)) {
						throw new Error(`Not equal user ${users[i]._id}`, users[i].id);
					}
				});
			}
		} else if (dbusers.length > 0) {
			throw new Error('DB not empty');
		}

		/* Verify Agreements */
		let agreementBuffer = await agreementContract.getAgreements(client);
		let agreements = agreementBuffer;
		let dbagreements = await offchainDB.agreements.getAll();
		logger.debug('%s - Total DB Agreements: ', method, dbagreements.length);
		logger.debug('%s - Total BC Agreements: ', method, agreements.length);

		// Check lengths
		if (dbagreements.length !== agreements.length) {
			throw new Error('Not equal total number of agreements');
		}

		// Check all Agreement Documents to match
		if (Array.isArray(agreements) && agreements.length) {
			for (let i = 0; i < agreements.length; i++) {
				await offchainDB.agreements.getById(agreements[i].txID).then((res) => {
					if (!Util.isEqualCommonProperties(agreements[i], res)) {
						throw new Error(`Not equal agreement ${agreements[i]._id}`);
					}
				});
			}
		} else if (dbagreements.length > 0) {
			throw new Error('DB not empty');
		}

		return(true);
	} catch(e) {
		logger.error('%s - ', method, e.message);
		throw e;
		// return(false);
	}
}

/**
 * Run validator continuously
 */
async function runValidate() {
	const method = 'runValidate';
	await offchainDB.connect();

	setInterval(async () => {
		await validateDB()
			.then((res) => {
				logger.info('%s - Valid: ', method, res);
			})
			.catch((err) => {
				logger.info('%s - Valid: false', method, err);
			});
	}, 5*1000);
}

(async() => {

	let args = process.argv.slice(2);
	let mode = args[0]

	if (mode === 'listen') {
		try {
			const listener = await BlockListener.createBlockListener(client, channelID);
		} catch(e) {
			logger.error(e)
			throw e
		}
		// await BlockListener.removeBlockListener(client, channelID, listener);
	}
	else if (mode === 'val') {
		await runValidate();
	} 
	else if (mode === 'drop') {
		await offchainDB.connect();
		await offchainDB.drop();
		await offchainDB.disconnect()
	} 
	else if (mode === 'test') {
		let err 
		try {
			const listener = await BlockListener.createBlockListener(client, channelID);
			// wait X seconds for data to be stored in DB
			let sec = 10
			await Util.sleep(sec * 1000).then( async() => {
				await BlockListener.removeBlockListener(client, channelID, listener);
			})

			await offchainDB.connect();
			await validateDB();
			console.log('\x1b[32m\u2714\x1b[0m Database is synced with Blockchain');
		} catch(e) {
			logger.error(e)
			console.log('\x1b[31m\u2716\x1b[0m Database Validation Failed');
			err = e
			throw e
		} finally {
			offchainDB.disconnect()
			if (err) {
				process.exit(err)
			} else {
				process.exit(0)
			}
		}
	}
})();

// main();
