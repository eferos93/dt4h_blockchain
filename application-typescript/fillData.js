/*
 * Copyright Streamr 2020. All Rights Reserved.
 *
 * Author: Alexandros Tragkas
 */

'use strict';

const process = require('process');
const _ = require('lodash');
require('dotenv').config();

// Require relevant libs
const {
	UserContract,
	DataContract,
	AgreementContract,
	BlockListener,
	QueryDB,
	OffchainDB,
	CAServices,
	Crypto,
	Util
} = require('./kraken-app');

const sleep = Util.sleep;
const prettyJSON = Util.prettyJSON;

// console.log(process.env.HFC_LOGGING)

// Client
const clientID = process.env.CLIENT;

// Channel Data
const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;
const BLOCK_DELAY = process.env.BLOCK_DELAY;
const registrar = process.env.REGISTRAR;

// User Input
// Test specifics
let secret = 'secret';
let orgMSP = 'LynkeusUsersMSP';
let org = 'lynkeus';

let appUserRole = 'client';

let listener;
let result;
let appUserId;
let purposeArr = [];
let numOfUsers = 2;
let purposeNum;
let user;
let userPrefix = 'tttestuser'

let purposes = ['Marketing', 'PubliclyFundedResearch', 'Business', 'PrivateResearch', 'AutomatedDecisionMaking'];
let dataContract = new DataContract(channelID, chaincodeID);
let userContract = new UserContract(channelID, chaincodeID);
let agreementContract = new AgreementContract(channelID, chaincodeID);
let lynkeusCA = new CAServices('lynkeus', 'ca-lynkeus', 'LynkeusMSP', 'lynkeusRegistrar');

/* Fills testing data of users with multiple products each */
async function main() {

	let args = process.argv.slice(2);

	try {
		// listener = await BlockListener.createBlockListener(user, channelID);

		if (args[0] === 'user') {

			let userObj;

			for (let i = 0; i < numOfUsers; i++) {
				appUserId = userPrefix + i;
				await lynkeusCA.registerAppUser(appUserId, appUserRole, secret);
				await lynkeusCA.enrollAppUser(appUserId, secret);
			}

			await sleep(BLOCK_DELAY);

			for (let i = 0; i < numOfUsers; i++) {
				user = userPrefix + i;
				purposeArr = _.sampleSize(purposes, 2);
				while (!purposeArr.length) {
					purposeArr = _.sampleSize(purposes, 2);
				}
				userObj = {
					username: user,
					isOrg:true,
					org: {
						instType:'Private Hospital',
						orgName:'Lynkeus',
						dpoFirstName:'Bob',
						dpoLastName:'Bobinson',
						dpoEmail:'Bob@email.com',
						active:true,
					},
					isBuyer:true,
					purposes: purposeArr
				};

				console.log('Submit CreateUser transaction...');
				await userContract.createUser(user, userObj);
			}
			await sleep(BLOCK_DELAY);

		}

		let product = {
			name:'prodName1',
			price:10,
			desc:'An analytics product',
			curations: [],
			productType: 'default',
			policy: {
				inclPersonalInfo:true,
				hasconsent:true,
				purposes:[
					'Marketing',
					'Business'
				], 
				protectionType:'SMPC',
				secondUseConsent:true,
				recipientType:'',
				transferToCountry:false,
				storagePeriod:20
			},
			escrow: '',
			productIDs: []
		};

		let count = 10;

		for (let i = 0; i < 1; i++) {
			await setInterval(async function() {
				let err = await dataContract.createProduct(userPrefix + i, product);
				// console.log(product);
				// console.log('Error?\t ',  err);
				purposeNum = Math.floor(Math.random() * Math.floor(3));

				// product.policy.purposes = _.sampleSize(purposes, purposeNum);
				// while (!product.policy.purposes.length) {
				// 	product.policy.purposes = _.sampleSize(purposes, 2);
				// }
				product.price = Math.random()*1000;
				product.storagePeriod = (Math.random()*100);
				count += 10;
			}, BLOCK_DELAY);
		}
		// await setInterval(async function() {
		// 	await dataContract.createProduct('user1', product);
		// 	product.price = Math.random()*1000;
		// 	product.policy.storagePeriod = Math.floor(Math.random()*100);
		// 	count += 10;
		// }, BLOCK_DELAY);

		// await setInterval(async function() {
		// 	await dataContract.createProduct('user2', product);
		// 	product.price = Math.random()*1000;
		// 	product.policy.storagePeriod = Math.floor(Math.random()*100);
		// 	count += 10;
		// }, BLOCK_DELAY);

		// await setInterval(async function() {
		// 	await dataContract.createProduct('', product);
		// 	product.price = Math.random()*1000;
		// 	product.policy.storagePeriod = Math.floor(Math.random()*100);
		// 	count += 10;
		// }, BLOCK_DELAY);

		// await setInterval(async function() {
		// 	await DataContract.createProduct('user3', product);
		// 	product.price = Math.random()*1000;
		// 	product.policy.storagePeriod = Math.floor(Math.random()*100);
		// 	count += 10;
		// }, BLOCK_DELAY);

		// await setInterval(async function() {
		// 	await dataContract.createProduct('user4', product);
		// 	product.price = Math.random()*1000;
		// 	product.policy.storagePeriod = Math.floor(Math.random()*100);
		// 	count += 10;
		// }, BLOCK_DELAY);



		// await BlockListener.removeBlockListener(user, channelID, listener);
	} catch(e) {
		console.log(e);
	}
}

main();