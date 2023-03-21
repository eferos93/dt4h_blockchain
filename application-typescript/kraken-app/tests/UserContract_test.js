/*
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * Author: Alexandros Tragkas
 */

'use strict';

const { UserContract, DataContract } = require('../index');
const { sleep } = require('../dist/libUtil');
const test_data = require('./test_data');

require('dotenv').config();

const _ = require('lodash');
const assert = require('chai').assert;
const expect = require('chai').expect;

const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;
const BLOCK_DELAY = process.env.BLOCK_DELAY;
const username = 'user0';
const clientID = username;
const clientID_2 = 'buyer'

// Init
let userContract = new UserContract(channelID, chaincodeID);
let dataContract = new DataContract(channelID, chaincodeID);

const user0 = test_data.getUser(username)
let userObj = _.cloneDeep(user0)

const org = test_data.getUser('org0')
const orgObj = _.cloneDeep(org)

const institutional_buyer = test_data.getUser('institutional_buyer')
const instBObj = _.cloneDeep(institutional_buyer)

let buyerObj = _.cloneDeep(test_data.getUser(clientID_2))

let product = _.cloneDeep(test_data.product_batch_automated)

console.log(product)
describe('==== Lib UserContract ====', async function () {
	this.timeout(100000);

	// Create
	context('1st CRUD', async function () {
		it('Creates User', async function () {
			let res = await userContract.createUser(clientID, userObj);
			expect(res).not.to.be.a('error')
			await sleep(BLOCK_DELAY*1.5);
		});

		// Read
		it('Reads User', async function () {
			// this.timeout(5000);
			let res = await userContract.readUser(clientID, username);
			assert.equal(res.org.instType, '', 'Not initializing .org for non org');
			assert.equal(res.purposes[0], userObj.purposes[0], 'Not equal purpose');

		});

		// Update
		it('Updates User', async function () {
			userObj.purposes = ['AutomatedDecisionMaking'];
			await userContract.updateUser(clientID, userObj);
			await sleep(BLOCK_DELAY);
			let res = await userContract.readUser(clientID, username);
			assert.equal(
				res.purposes[0],
				userObj.purposes[0],
				'Not equal purpose'
			);
		});

		// Delete
		it('Deletes User And Products', async function () {
			await dataContract.createProduct(clientID, product);
			await sleep(BLOCK_DELAY);
			await userContract.deleteUser(clientID, username);
			await sleep(BLOCK_DELAY);
			let res = await userContract.readUser(clientID, username);
			assert.equal(res, null);
		});
	});

	context('2nd CRUD', async function () {
		it('Creates User', async function () {
			let res = await userContract.createUser(clientID, userObj);
			expect(res).not.to.be.a('error')
			await sleep(BLOCK_DELAY*1.5);
		});

		// Read
		it('Reads User', async function () {
			// this.timeout(5000);
			let res = await userContract.readUser(clientID, username);
		});

		// Update
		it('Updates User', async function () {
			userObj.purposes = ['AutomatedDecisionMaking'];
			await userContract.updateUser(clientID, userObj);
			await sleep(BLOCK_DELAY);
			let res = await userContract.readUser(clientID, username);
			assert.equal(
				res.purposes[0],
				userObj.purposes[0],
				'Not equal purpose'
			);
		});

		// Delete
		it('Deletes User And Products', async function () {
			await dataContract.createProduct(clientID, product);
			await sleep(BLOCK_DELAY);
			await userContract.deleteUser(clientID, username);
			await sleep(BLOCK_DELAY);
			let res = await userContract.readUser(clientID, username);
			assert.equal(res, null);
		});
	});

	context('Validations', async function () {
		// it('Rejects both Member and Org', async function () {
		// 	userObj.isOrg = true
		// 	userObj.isMemberOf = "asdf"
		// 	console.log(userObj)
		// 	let res = await userContract.createUser(clientID, userObj);
		// 	expect(res).to.be.a('error');
		// 	userObj = _.cloneDeep(user0)
		// });

		it('Rejects Org institution type random value', async function () {
			userObj.isOrg = true
			userObj.org.instType = "random"
			let res = await userContract.createUser(clientID, userObj);
			console.log('fdfdsdsf')
			expect(res).to.be.a('error');
			userObj = _.cloneDeep(user0)
		});

		it('Rejects missing Org name', async function () {
			userObj.isOrg = true
			userObj.org.orgName = ""
			let res = await userContract.createUser(clientID, userObj);
			expect(res).to.be.a('error');
			userObj = _.cloneDeep(user0)
		});

		it('Rejects already registered user and username', async function () {
			await userContract.createUser(clientID, userObj);
			await sleep(BLOCK_DELAY)
			
			// already registered
			let res = await userContract.createUser(clientID, userObj);
			expect(res).to.be.a('error');
			
			// username exists
			res = await userContract.createUser(clientID_2, userObj);
			expect(res).to.be.a('error');
			await userContract.deleteUser(clientID, username);
			await sleep(BLOCK_DELAY);			
		});

		it('Rejects being Member of non existing Org', async function () {
			userObj.isMemberOf = "asdasd"
			let res = await userContract.updateUser(clientID, userObj)
			expect(res).to.be.a('error');
			userObj = _.cloneDeep(user0)
		});

		it('Appends member to Org.Members', async function () {
			// Create Org
			// orgObj.org.members.append(instBObj.username)
			await userContract.createUser(orgObj.username, orgObj);
			await sleep(BLOCK_DELAY)
			
			await userContract.createUser(instBObj.username, instBObj);
			await sleep(BLOCK_DELAY)


			// buyerObj.isMemberOf = orgObj.username
			// console.log(buyerObj)
			// await userContract.createUser(buyerObj, buyerObj);
			// await sleep(BLOCK_DELAY)

			// // already registered
			let orgUser = await userContract.readUser(clientID, org.username)
			let instBuyer = await userContract.readUser(clientID, institutional_buyer.username)
			
			// Append member to Org's members
			orgUser.org.members = [instBuyer.id]
			await userContract.updateUser(orgObj.username, orgUser);
			await sleep(BLOCK_DELAY)
			
			orgUser = await userContract.readUser(clientID, org.username)

			// console.log(orgUser)
			// console.log(instBuyer)
			assert.equal(orgUser.org.members[orgUser.org.members.length - 1], instBuyer.id, 'Member not joined on org user');
			await userContract.deleteUser(orgObj.username, orgObj.username);
			await sleep(BLOCK_DELAY);

			await userContract.deleteUser(instBObj.username, instBObj.username);
			await sleep(BLOCK_DELAY);
		});

	});

});
