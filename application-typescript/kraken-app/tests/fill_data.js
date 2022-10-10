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
	// AgreementContract,
	CAServices,
	Util,
} = require('../index');

const sleep = Util.sleep;

// console.log(process.env.HFC_LOGGING)

// Channel Data
const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;
const BLOCK_DELAY = process.env.BLOCK_DELAY;

// User Input
// Test specifics
let secret = 'secret';

let appUserRole = 'client';

let appUserId;
let purposeArr = [];
let numOfUsers = 3;
let purposeNum;
let user;

let purposes = [
	'Marketing',
	'PubliclyFundedResearch',
	'Business',
	'PrivateResearch',
	'AutomatedDecisionMaking',
];
let dataContract = new DataContract(channelID, chaincodeID);
let userContract = new UserContract(channelID, chaincodeID);
// let agreementContract = new AgreementContract(channelID, chaincodeID);

let registrar = process.env.REGISTRAR;

let ca;
if (registrar === 'lynkeusRegistrar') {
	ca = new CAServices('lynkeus', 'ca-lynkeus', 'LynkeusMSP', registrar);
} else {
	ca = new CAServices('tex', 'ca-tex', 'TexMSP', registrar);
}

/* Fills testing data of users with multiple products each */
async function main() {

	try {
		let userObj;

		for (let i = 0; i < numOfUsers; i++) {
			appUserId = 'user' + i;
			await ca.registerAppUser(appUserId, appUserRole, secret);
			await ca.enrollAppUser(appUserId, secret);
		}

		await sleep(BLOCK_DELAY);

		for (let i = 0; i < numOfUsers; i++) {
			user = 'user' + i;
			purposeArr = _.sampleSize(purposes, 2);
			while (!purposeArr.length) {
				purposeArr = _.sampleSize(purposes, 2);
			}
			userObj = {
				username: user,
				isOrg: true,
				org: {
					instType: 'Private Hospital',
					orgName: 'Lynkeus',
					dpoFirstName: 'Bob',
					dpoLastName: 'Bobinson',
					dpoEmail: 'Bob@email.com',
					active: true,
				},
				isBuyer: true,
				purposes: purposeArr,
			};

			await userContract.createUser(user, userObj);
		}
		await sleep(BLOCK_DELAY);

		let product = {
			name: 'prodName1',
			price: 10,
			desc: 'An analytics product',
			curations: [],
			productType: 'analytics',
			policy: {
				inclPersonalInfo: true,
				hasconsent: true,
				purposes: ['Marketing', 'Business'],
				protectionType: 'SMPC',
				secondUseConsent: true,
				recipientType: '',
				transferToCountry: false,
				storagePeriod: 20,
			},
			escrow: '',
			productIDs: [],
		};

		// let count = 10;

		for (let i = 0; i < 3; i++) {
			// let productID =
			await dataContract.createProduct(
				'user' + i,
				product,
				channelID,
				chaincodeID
			);
			// console.log(product);
			// console.log('Error?\t ',  err);
			purposeNum = Math.floor(Math.random() * Math.floor(3));

			product.policy.purposes = _.sampleSize(purposes, purposeNum);
			while (!product.policy.purposes.length) {
				product.policy.purposes = _.sampleSize(purposes, 2);
			}
			product.price = Math.random() * 1000;
			product.storagePeriod = Math.random() * 100;
			// count += 10;
		}
	} catch (e) {
		console.log(e);
	}
}

main();
