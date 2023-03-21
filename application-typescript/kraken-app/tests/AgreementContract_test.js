/*
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * Author: Alexandros Tragkas
 */

'use strict';

const { DataContract, AgreementContract, Util } = require('../index');
const sleep = Util.sleep;
const _ = require('lodash');

require('dotenv').config();

const assert = require('chai').assert;
const expect = require('chai').expect;

const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;
const BLOCK_DELAY = process.env.BLOCK_DELAY;
const username = process.env.USERNAME;
const adminID = process.env.CLIENT;
const test_data = require('./test_data');
const t = require('./consts')

// Init
// let userContract = new UserContract(channelID, chaincodeID);
let dataContract = new DataContract(channelID, chaincodeID);
let agreementContract = new AgreementContract(channelID, chaincodeID);

const nonClientID = process.env.PEER_ID;
const clientID = 'user0';
const orgID = 'org0'
const sellerID = 'seller';
const buyerID = 'buyer';

const orgUser = test_data.getUser(orgID)
const seller = test_data.getUser(sellerID)
const buyer = test_data.getUser(buyerID)

let product = _.cloneDeep(test_data.product_batch_automated)

let orgObj = _.cloneDeep(orgUser)
let sellerObj = _.cloneDeep(seller)
let buyerObj = _.cloneDeep(buyer)



describe('==== Lib AgreementContract ====', async function () {
	this.timeout(20000);
	let productID;
	let transactionID;

	context('Agreement Lifecycle', async function () {

		it('Should Create Agreement with status: Eligible', async function () {
			let res = await dataContract.createProduct(sellerID, product);
			await sleep(BLOCK_DELAY);
			expect(res).to.be.a('string');
			productID = res;

			const buyerParams = {
				purposes: [t.P_AUTOMATED],
			};

			res = await dataContract.buyProduct(buyerID, productID, buyerParams);
			expect(res).to.not.be.a('error');

			transactionID = res;
			await sleep(BLOCK_DELAY);
			res = await agreementContract.getAgreement(adminID, transactionID).then(console.log(res))
			expect(res).to.have.property('status', 'Eligible');
		});

		it('Should Update Agreement to: Paid (Admin)', async function () {
			let res = await agreementContract.updateAgreement(adminID, transactionID, 'Paid');
			assert.equal(res, '', 'error on update agreement');
			await sleep(BLOCK_DELAY);
			
			res = await agreementContract.getAgreement(adminID, transactionID);
			expect(res).to.have.property('status', 'Paid');
		});

		it('Should Update Agreement to: Access (Admin)', async function () {
			let res = await agreementContract.updateAgreement(
				adminID,
				transactionID,
				'Access'
			);
			assert.equal(res, '', 'error on update agreement');
			await sleep(BLOCK_DELAY);
			res = await agreementContract.getAgreement(adminID, transactionID);
			expect(res).to.have.property('status', 'Access');
		});
	});

	context('Validations', async function () {

		it('Should reject non Eligible/Paid/Access status', async function() {
			let res = await agreementContract.updateAgreement(
				adminID,
				transactionID,
				'Illegal'
			);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);
			res = await agreementContract.getAgreement(adminID, transactionID);
			expect(res).to.have.property('status', 'Access');

		});
	});

	context('Permission checks', async function () {
		it('Should reject Non $MainMSP (LynkeusMSP / TexMSP)', async function() {
			let res = await agreementContract.updateAgreement(
				sellerID,
				transactionID,
				'Paid'
			);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);
			res = await agreementContract.getAgreement(adminID, transactionID);
			expect(res).to.have.property('status', 'Access');

		});

		it('Should reject non Client role', async function() {
			let res = await agreementContract.updateAgreement(
				nonClientID,
				transactionID,
				'Paid'
			);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);
			res = await agreementContract.getAgreement(adminID, transactionID);
			expect(res).to.have.property('status', 'Access');

		});
	});

});
