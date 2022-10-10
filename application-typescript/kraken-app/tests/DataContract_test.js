/*
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * Author: Alexandros Tragkas
 */

'use strict';

const { UserContract, DataContract, Util } = require('../index');
const _ = require('lodash');
const sleep = Util.sleep;
const assert = require('chai').assert;
const expect = require('chai').expect;
require('dotenv').config();
const test_data = require('./test_data');

const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;
const BLOCK_DELAY = process.env.BLOCK_DELAY;

// Init
let userContract = new UserContract(channelID, chaincodeID);
let dataContract = new DataContract(channelID, chaincodeID);

let product = _.cloneDeep(test_data.product_batch_automated)
let product_2 = _.cloneDeep(test_data.product_analytics)
let product_tmp_batch = _.cloneDeep(product);
let product_tmp_analytics = _.cloneDeep(product_2);
let product_tmp_edu_batch = _.cloneDeep(test_data.educational_product_batch)
let product_tmp_edu_analytics = _.cloneDeep(test_data.educational_product_analytics)
let product_preapproved_user = _.cloneDeep(test_data.product_preapproved_user)

const org0 = 'org0'
const org1 = 'org1'
const sellerID = 'seller';
const buyerID = 'buyer';

const orgUser = test_data.getUser(org0)
const orgUser_1 = test_data.getUser(org1)
const seller = test_data.getUser(sellerID)
const buyer = test_data.getUser(buyerID)

let orgObj = _.cloneDeep(orgUser)
let orgObj_1 = _.cloneDeep(orgUser_1)
let sellerObj = _.cloneDeep(seller)
let buyerObj = _.cloneDeep(buyer)

describe('==== Lib DataContract ====', async function() {
	this.timeout(20000);
	let productID;
	let productID_preapproved;
	context('Is owner - CRUD', function() {
		it('Creates Product', async function() {
			let res = await userContract.readUser(sellerID, sellerID);
			if (!res) {
				await userContract.createUser(sellerID, sellerObj);
				await sleep(BLOCK_DELAY);
			}

			res = await userContract.readUser(buyerID, buyerID);
			if (!res) {
				await userContract.createUser(buyerID, buyerObj);
				await sleep(BLOCK_DELAY);
			}			
			res = await dataContract.createProduct(sellerID, product);
			expect(res).to.be.a('string');
			productID = res;
			await sleep(BLOCK_DELAY);
		});

		it('Reads Product', async function() {
			let res = await dataContract.readProduct(sellerID, productID);

			expect(res).to.be.a('object');
			expect(res).to.have.property('price', 10);
			assert.equal(res.policy.purposes[0], product.policy.purposes[0], 'Non matching policies');
		});

		it('Updates Product', async function() {
			product.id = productID;
			product.price = 20;
			product.policy.purposes = ['marketing'];
			let res = await dataContract.updateProduct(sellerID, product);
			expect(res).to.equal('');
			await sleep(BLOCK_DELAY);

			res = await dataContract.readProduct(sellerID, productID);
			expect(res).to.have.property('price', 20);
			assert.equal(res.policy.purposes[0], product.policy.purposes[0], 'Non matching policies');
			product = _.cloneDeep(test_data.product_batch_automated)
		});

		it('Deletes Product', async function() {
			let res = await dataContract.deleteProduct(sellerID, productID);
			expect(res).to.equal(null);
			await sleep(BLOCK_DELAY);

			res = await dataContract.readProduct(sellerID, productID);
			expect(res).to.be.a('error')
		});
	});

	context('Is not Owner - Permission checks CRUD', function() {
		it('Cannot Update Product', async function() {
			let res = await dataContract.createProduct(sellerID, product);
			expect(res).to.be.a('string');
			productID = res;
			await sleep(BLOCK_DELAY);

			product.id = productID;
			product.price = 30;
			console.log(buyerID, product)
			res = await dataContract.updateProduct(buyerID, product);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);

			res = await dataContract.readProduct(sellerID, productID);
			expect(res).to.have.property('price', 10);
		});

		it('Cannot Delete Product', async function() {
			let res = await dataContract.deleteProduct(buyerID, productID);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);

			res = await dataContract.readProduct(sellerID, productID);
			expect(res).to.be.a('object');
			assert.equal(res.policy.purposes[0], product.policy.purposes[0], 'Non matching policies');
		});

	});

	context('Curation', function() {
		it('Create Curated Product', async function() {

			// Create product
			let res = await dataContract.createProduct(sellerID, product);
			expect(res).to.be.a('string');
			productID = res;
			await sleep(BLOCK_DELAY);

			// Create 1st curation
			let product_curated = _.cloneDeep(product);
			product_curated.curations = [];
			product_curated.curations.push(productID);
			res = await dataContract.createProduct(sellerID, product_curated);
			expect(res).to.be.a('string');
			let productID_curated = res;
			await sleep(BLOCK_DELAY);

			// Curations[0] should be productID of Base Product
			res = await dataContract.readProduct(sellerID, productID_curated);
			expect(res).to.be.a('object');
			assert.equal(res.curations[0], productID, 'Non matching ProductID on Product.curation');
			assert.equal(res.curations[1], null, 'Non Empty Product.curation[1]');

			// Create 2nd curation
			let product_curated_2 = _.cloneDeep(product);
			product_curated_2.curations = [];
			product_curated_2.curations.push(productID, productID_curated);
			res = await dataContract.createProduct(sellerID, product_curated_2);
			expect(res).to.be.a('string');
			let productID_curated_2 = res;
			await sleep(BLOCK_DELAY);

			// Curations[0] should be productID of 1st Product
			// Curations[1] should be productID of base Product
			res = await dataContract.readProduct(sellerID, productID_curated_2);
			expect(res).to.be.a('object');
			assert.equal(res.curations[0], productID, 'Non matching 1st ProductID on Product.curation');
			assert.equal(res.curations[1], productID_curated, 'Non matching 2nd ProductID on Product.curation');
			assert.equal(res.curations[2], null, 'Non Empty Product.curation[2]');
		});

		it('Should error if base product does not exist', async function() {
			product_tmp_batch.curations = ['9ef6b6b6ce1f83a2465b424478916273afafe1fee1138baa8fc38b0526fb98c2'];

			let res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('error');

			product_tmp_batch = _.cloneDeep(product);
			await sleep(BLOCK_DELAY);
		});

	});

	context('Validations', function() {
		it('Should error on inclPersonalInfo=true and hasConsent=false', async function() {
			product_tmp_batch.policy.inclPersonalInfo = true;
			product_tmp_batch.policy.hasConsent = false;

			let res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('error');

			product_tmp_batch = _.cloneDeep(product);
			await sleep(BLOCK_DELAY);
		});

		it('Should error on empty/wrong value of Sector/ProductType', async function() {
			product_tmp_batch.Sector = '';

			let res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);

			product_tmp_batch.Sector = 'Unknown';
			res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('error');

			product_tmp_batch.Sector = 'BATCH';
			product_tmp_batch.productType = 'Unknown'
			res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('error');

			product_tmp_batch = _.cloneDeep(product);
			await sleep(BLOCK_DELAY);
		});

		it('Should error on empty ApprovedOrgs value for HEALTH', async function() {
			product_tmp_batch.policy.approvedOrgs = [];

			let res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('error');
			await sleep(BLOCK_DELAY);

			product_tmp_batch = _.cloneDeep(product);
			await sleep(BLOCK_DELAY);
		});

		context('Validations - BATCH / STREAMS', function() {

			it('Should error on empty/wrong value of policy.Purposes for BATCH/STREAMS', async function() {
				product_tmp_batch.policy.purposes = [];
				product_tmp_batch.productType = 'BATCH'

				let res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);

				product_tmp_batch.policy.purposes = ['Unknown'];
				res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('error');

				product_tmp_batch = _.cloneDeep(product);
				await sleep(BLOCK_DELAY);
			});


			it('Should not error on empty/unknown policy.Purposes for analytics', async function() {
				product_tmp_batch.policy.purposes = [];
				product_tmp_batch.productType = 'ANALYTICS'

				let res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('string');
				await sleep(BLOCK_DELAY);

				product_tmp_batch.policy.purposes = ['Unknown'];
				res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('string');

				product_tmp_batch = _.cloneDeep(product);
				await sleep(BLOCK_DELAY);
			});


			it('Should error on empty/wrong InstitutionTypes', async function() {
				product_tmp_batch.policy.recipientType = [];
				product_tmp_batch.sector = 'Education'
				let res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);

				product_tmp_batch.policy.recipientType = ['Unknown'];
				res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);
				
				product_tmp_batch = _.cloneDeep(product);
				await sleep(BLOCK_DELAY);
			});

			it('Should error on empty/wrong Automated Consequences', async function() {
				product_tmp_batch.policy.purposes = ['automated']
				product_tmp_batch.policy.automated = []
				let res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);

				product_tmp_batch.policy.automated = ['automated'];
				res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);
				
				product_tmp_batch = _.cloneDeep(product);
				await sleep(BLOCK_DELAY);
			});			
		});

		context('Validations - ANALYTICS', function() {

			it('Should error on empty/wrong InstitutionTypes', async function() {
				product_tmp_analytics.policy.recipientType = [];
				product_tmp_analytics.sector = 'Health'
				let res = await dataContract.createProduct(sellerID, product_tmp_analytics);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);

				product_tmp_analytics.policy.recipientType = ['Unknown'];
				res = await dataContract.createProduct(sellerID, product_tmp_analytics);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);

				product_tmp_analytics = _.cloneDeep(product_2);
				await sleep(BLOCK_DELAY);
			});

			it('Should error on empty InstitutionTypes for Analytics', async function() {
				product_tmp_analytics = [];
				product_tmp_analytics.sector = 'Health'
				let res = await dataContract.createProduct(sellerID, product_tmp_analytics);
				expect(res).to.be.a('error');
				await sleep(BLOCK_DELAY);

				product_tmp_analytics = _.cloneDeep(product_2);
				await sleep(BLOCK_DELAY);
			});	
		});
	});

	context('Buy Product', function() {
		let orgFabricID
		let buyerParams = {
				purposes: ['publicly_funded_research']
		};

		let res
		before(async function() {
			res = await userContract.readUser(org0, org0);
			if (!res) {
				await userContract.createUser(org0, orgObj);
				await sleep(BLOCK_DELAY);
			}

			res = await userContract.readUser(org0, org0)
			orgFabricID = res.id

			res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('string');
			productID = res;
			await sleep(BLOCK_DELAY);
		});

		it('Should error on owner buying own product', async function() {
			let res = await dataContract.createProduct(sellerID, product_tmp_batch);
			expect(res).to.be.a('string');
			productID = res;
			await sleep(BLOCK_DELAY);

			res = await dataContract.buyProduct(sellerID, productID, buyerParams);
			expect(res).to.be.a('error');
		});

		it('Should error if BuyerID is not in Org.Members (Unverified)', async function() {
			// res = await userContract.readUser(org1, org1);
			// if (!res) {
			// 	await userContract.createUser(org1, orgObj_1);
			// 	await sleep(BLOCK_DELAY);
			// }

			// BuyerID not belonging to the Org's Members
			buyerObj.isMemberOf = org0
			await userContract.updateUser(buyerID, buyerObj)
			await sleep(BLOCK_DELAY);

			orgObj.org.members = []
			await userContract.updateUser(org0, orgObj)
			await sleep(BLOCK_DELAY);

			res = await dataContract.buyProduct(buyerID, productID, buyerParams);
			expect(res).to.be.a('error');

		});

		// Check for expired Cert TODO
		// Check for revoked Cert


		context('Buy Product - HEALTH', function() {
			let res			
			let buyerParams = {
				purposes: ['publicly_funded_research']
			};

			before(async function() {
				// Create Product
				product_tmp_batch.policy.approvedOrgs = ['asd']
				res = await dataContract.createProduct(sellerID, product_tmp_batch);
				expect(res).to.be.a('string');
				productID = res;
				await sleep(BLOCK_DELAY);

				// Create preapproved user product
				res = await dataContract.createProduct(sellerID, product_preapproved_user)
				expect(res).to.be.a('string');
				productID_preapproved = res;
				await sleep(BLOCK_DELAY);

				// Add buyer to Org
				res = await userContract.readUser(buyerID, buyerID)

				orgObj.org.members = [res.id]
				await userContract.updateUser(org0, orgObj)
				await sleep(BLOCK_DELAY);
			});

			it('Reject if org is not Pre Approved', async function() {
				res = await dataContract.buyProduct(buyerID, productID, buyerParams);
				expect(res).to.be.a('error');
			});

			it('Buys product if Buyer is a PreApproved User', async function() {
				res = await dataContract.buyProduct(buyerID, productID_preapproved, {purposes: []})
				expect(res).to.be.a('string');
			})

			context('BATCH/STREAMS', function() {
				before(async function() {
					product_tmp_batch = _.cloneDeep(test_data.product_batch_automated)
					res = await dataContract.createProduct(sellerID, product_tmp_batch);
					expect(res).to.be.a('string');
					productID = res;
					await sleep(BLOCK_DELAY);
				});

				it('Eligible on Matching Purposes and PreApproved Org', async function() {
					// Create product
					res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('string');
				});

				it('Should error on Non Matching Purposes', async function() {
					buyerParams.purposes = ['marketing']

					res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('error');
				});

				it('Should error on partially matching Purposes', async function() {
					buyerParams.purposes = ['marketing', 'automated']

					res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('error');
				});

			});

			context('ANALYTICS', function() {
				before(async function() {
					// Create Product
					res = await dataContract.createProduct(sellerID, product_tmp_analytics);
					expect(res).to.be.a('string');
					productID = res;
					await sleep(BLOCK_DELAY);
				});

				it('Should error on Non Matching Institution Type', async function() {
					orgObj.org.instType = 'privateResearch'
					await userContract.updateUser(org0, orgObj)
					await sleep(BLOCK_DELAY*1.5);					

					res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('error');
				});

				it('Should buy on Matching Institution type', async function() {
					orgObj.org.instType = product_tmp_analytics.policy.recipientType[0]
					await userContract.updateUser(org0, orgObj)
					await sleep(BLOCK_DELAY);

					res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('string');
				});
			});
		});

		context('Buy Product - EDUCATION', function() {
			let res			
			let buyerParams = {
				purposes: ['publicly_funded_research']
			};

			before(async function() {
				// Create Product
				res = await dataContract.createProduct(sellerID, product_tmp_edu_batch);
				expect(res).to.be.a('string');
				productID = res;
				await sleep(BLOCK_DELAY*1.5);

				// Add buyer to Org
				res = await userContract.readUser(buyerID, buyerID)

				orgObj.org.members = [res.id]
				orgObj.org.instType = 'private_companies'
				await userContract.updateUser(org0, orgObj)
				await sleep(BLOCK_DELAY);
			});

			it('Should error on Non Matching Institution Type', async function() {

				res = await dataContract.buyProduct(buyerID, productID, buyerParams);
				expect(res).to.be.a('error');
			});
			
			context('BATCH/STREAMS', function() {
				it('Should error on Non Matching Purposes', async function() {
					orgObj.org.instType = 'hr_agencies'
					await userContract.updateUser(org0, orgObj)
					await sleep(BLOCK_DELAY);					

					let res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('error');
				});

				it('Eligible on Matching Purposes and Institution Type', async function() {
					buyerParams.purposes = ['marketing']
					res = await dataContract.buyProduct(buyerID, productID, buyerParams);
					expect(res).to.be.a('string');
				});

			});
		});
	});

});