/*
 *
 * Author: Alexandros Tragkas
 */

'use strict';

// Require relevant libs
const {
	UserContract,
	DataContract,
	AgreementContract,
	Query,
	OffchainDB,
	SignOffline,
	CAServices,
	Crypto,
	Util
} = require('./application');


const fs = require('fs');
require('dotenv').config();

const process = require('process');
const path = require('path');
const util = require('util');

// User Input
const client = process.env.CLIENT;
const channelID = process.env.CHANNEL_ID;
const chaincodeID = process.env.CHAINCODE_ID;
const BLOCK_DELAY = process.env.BLOCK_DELAY;
const registrar = process.env.REGISTRAR;
const walletPath = path.join(process.env.WALLET_PATH);
const revokedCertificates = path.resolve(process.env.REVOKED_CERTS_PATH);
const peerEndpoint = process.env.PEER_ENDPOINT
/**
 *  Init
 */
let dataContract = new DataContract(channelID, chaincodeID);
let userContract = new UserContract(channelID, chaincodeID);
let agreementContract = new AgreementContract(channelID, chaincodeID);

let ca;
if (registrar === 'lynkeusRegistrar') {
	ca = new CAServices('lynkeus', 'ca-lynkeus', 'LynkeusMSP', registrar, peerEndpoint);
} else {
	ca = new CAServices('tex', 'ca-tex', 'TexMSP', registrar, peerEndpoint);
}

let offchainDB = new OffchainDB();
let queryDB = new Query(offchainDB);

/* Pre-reqs:
 Network is up with peers and the ordering service
 Chaincode is committed to the channel
*/
async function main() {

	let args = process.argv.slice(2);
	let res = 2;
	let mode = args[0];

// 	let obj1 = {
// 	  type: 'product',
// 	  owner: 'seller',
// 	  id: '014f679feef316e1ac0436a0757270d21eb45f9db4ce3797a379b92c9c6fafcf',
// 	  name: 'PROD_BATCH_0',
// 	  price: 10,
// 	  desc: 'A simple blood test',
// 	  sector: 'Health',
// 	  productType: 'Batch',
// 	  policy: {
// 	    inclPersonalInfo: true,
// 	    hasConsent: true,
// 	    purposes: [ 'Automated', 'PubliclyFundedResearch' ],
// 	    protectionType: 'SMPC',
// 	    secondUseConsent: true,
// 	    recipientType: [ 'PublicHospitals', 'PrivateHospitals' ],
// 	    transferToCountry: 'eu',
// 	    storagePeriod: 20,
// 	    approvedOrgs: [ 'org0' ],
// 	    automated: [ 'AutomatedPlacing' ],
// 	    vers: 0
// 	  },
// 	  timestamp: 1679398363,
// 	  vers: 0
// 	}


// 	let obj2 = {
//   _id: '014f679feef316e1ac0436a0757270d21eb45f9db4ce3797a379b92c9c6fafcf',
//   type: 'product',
//   owner: 'seller',
//   id: '014f679feef316e1ac0436a0757270d21eb45f9db4ce3797a379b92c9c6fafcf',
//   name: 'PROD_BATCH_0',
//   price: 10,
//   desc: 'A simple blood test',
//   sector: 'Health',
//   productType: 'Batch',
//   policy: {
//     inclPersonalInfo: true,
//     hasConsent: true,
//     purposes: [ 'Automated', 'PubliclyFundedResearch' ],
//     protectionType: 'SMPC',
//     secondUseConsent: true,
//     recipientType: [ 'PublicHospitals', 'PrivateHospitals' ],
//     transferToCountry: 'eu',
//     storagePeriod: 20,
//     approvedOrgs: [ 'org0' ],
//     approvedUsers: [],
//     automated: [ 'AutomatedPlacing' ],
//     vers: 0,
//     _id: "64199a06337174dbcd9e49b4"
//   },
//   timestamp: 1679398363,
//   curations: [],
//   vers: 0,
//   __v: 0
// }


	// console.log(Util.isEqualCommonProperties(obj1, obj2))

	try {

	 	if (mode === 'init') {
			console.log('Initializing...');
			await ca.importMSP(client, false)
			await ca.importMSP('lynkeusRegistrar', true);
			await ca.importMSP('texRegistrar', true);
			await ca.importMSP('peer0Lynkeus', false);
			// fs.writeFileSync(process.env.BLOCK_PATH, '0');
			// await offchainDB.initDB();
			// console.log('Identities Imported');
		}
		else if (mode === 'export') {
			console.log('Example: node app.js export userID');
			await ca.exportMSP(args[1]);
		}
		else {
			await offchainDB.connect();

			if (mode === 'queryproducts') {
				console.log('Querying all products...');
				res = await offchainDB.products.getAll();
				console.log(util.inspect(res, false, null, true));
				console.log('Total: ', res.length);
			}
			else if (mode === 'queryusers') {
				console.log('Querying all users...');
				res = await queryDB.queryUsers();
				console.log(util.inspect(res, false, null, true));
				console.log('Total: ', res.length);
			}
			else if (mode === 'queryuser') {
				console.log('Querying user: ', args[1]);
				res = await offchainDB.users.getById(args[1]);
				console.log(util.inspect(res, false, null, true));
			}
			else if (mode === 'queryproduct') {
				console.log('Querying product: ', args[1]);
				res = await offchainDB.products.getById(args[1]);
				console.log(util.inspect(res, false, null, true));
			}
			else if (mode === 'queryproductsbyuser') {
				console.log('Querying products of user: ', args[1]);
				res = await queryDB.queryProductsByUser(args[1]);
				console.log(util.inspect(res, false, null, true));
				console.log('Total: ', res.length);
			}
			else if (mode === 'queryfiltered') {
				console.log('Example: node app.js queryfiltered user0');
				console.log('Querying filtered products of user: ', args[1]);
				
				res = await queryDB.queryFilteredCatalogue(args[1]);
				console.log(util.inspect(res, false, null, true));
				console.log('Total: ', res.length);
			}
			else if (mode === 'queryagreements') {
				let res = await offchainDB.agreements.getAll(client);
				console.log(res);
				console.log('Total: ', res.length);
			}
			// new
			else if (mode === 'gethistoryofproduct') {
				console.log('Example: node app.js gethistoryofproduct productID');
				let productID = args[1];

				let res = await dataContract.getHistory(client, productID);
				console.log(res);
			}
			else if (mode === 'buyproduct') {
				console.log('Simulating a buy product transaction for user: ', args[1]);
				if (!args[1] && !args[2] && !args[3]) {
					console.log('Missing arguments');
					console.log('Usage: node app.js buyproduct userID prodID purpose1 purpose2 ...');
					process.exit(1);
				}

				let k = 3;
				let purposeArr = [];
				while (args[k]) {
					purposeArr.push(args[k]);
					k++;
				}

				let buyerParams = {
					purposes: purposeArr
				};

				res = await dataContract.buyProduct(args[1], args[2], buyerParams);
				console.log(res);
			}
			else if (mode === 'regen') {
				console.log('Register enrolling using the centralised way');
				console.log('Example: node app.js regen userID');
				let userID = args[1];
				let appUserRole = 'client';
				let secret = 'secret';

				await ca.registerAppUser(userID, appUserRole, secret);
				const enrollment = await ca.enrollAppUser(userID, secret);
				console.log(enrollment);
			}
			else if (mode === 'csrenroll') {
				console.log('Register enrolling using Certificate Signing Request (Deployment way)');
				console.log('Example: node app.js csrenroll username orgMSP');

				let enrollingUser = args[1];
				let orgMSP = args[2];
				// console.log(adminUserId)
				let appUserRole = 'client';
				let secret = 'secret';

				// BE
				await ca.registerAppUser(enrollingUser, appUserRole, secret);

				// FE
				let CryptoMaterial = await Crypto.generateKeysCSR(enrollingUser, orgMSP);
				console.log(CryptoMaterial)				

				// BE
				CryptoMaterial.enrollment = await ca.enrollAppUser(enrollingUser, secret, CryptoMaterial.csr);
				console.log(CryptoMaterial.enrollment)
				const identity = Crypto.generateIdentity(CryptoMaterial);
				fs.writeFileSync(`wallet/${enrollingUser}.id`, JSON.stringify(identity));

			}
			else if (mode === 'testkey') {
				console.log(Crypto.isValidX509('-----BEGIN CERTIFICATE-----\nMIICSDCCAe+gAwIBAgIUUY7uBQDcelDelyDpt+b/q/+/KTMwCgYIKoZIzj0EAwIw\najEOMAwGA1UEBhMFSVRBTFkxEDAOBgNVBAgTB0xZTktFVVMxFDASBgNVBAoTC0h5\ncGVybGVkZ2VyMQ8wDQYDVQQLEwZGYWJyaWMxHzAdBgNVBAMTFmZhYnJpYy1jYS1z\nZXJ2ZXItdXNlcnMwHhcNMjIwMTE4MTEyMjAwWhcNMzcwMTEzMTEyNzAwWjAhMQ8w\nDQYDVQQLEwZjbGllbnQxDjAMBgNVBAMTBXVzZXIyMFkwEwYHKoZIzj0CAQYIKoZI\nzj0DAQcDQgAErYMJ854mvxTKI3AatKkYM1LC2gIsCWozubNOFccK6GETwZlXhj4d\nxwjZcKzRcicLdkof7zuD1gTAo+tJATqoG6OBuzCBuDAOBgNVHQ8BAf8EBAMCB4Aw\nDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUAKQj8E6wWnNTMZQgfCk8CAUDNDswHwYD\nVR0jBBgwFoAUb36pwwnNkrS7ILFNtN65eiSCJCUwWAYIKgMEBQYHCAEETHsiYXR0\ncnMiOnsiaGYuQWZmaWxpYXRpb24iOiIiLCJoZi5FbnJvbGxtZW50SUQiOiJ1c2Vy\nMiIsImhmLlR5cGUiOiJjbGllbnQifX0wCgYIKoZIzj0EAwIDRwAwRAIgP8mj7jAT\ngANqyrdH6OHQexbBntJOTKlE8mKBc5md9voCIDLm1dKvTPLjOgKLnTn6SAQEoSP9\nQtYqX7dPHCbB5pui\n-----END CERTIFICATE-----'))
			}
			// else if (mode === '')
			else if (mode === 'reenroll') {
				console.log('Reenrolling....');
				console.log('Example: node app.js reenroll user0 lynkeus');

				try {

					// FE
					// Get Identity
					let user = args[1];

					const userCtx = await ca.getIdentityContextFromWallet(user);
					const userSigningIdentity = userCtx.getSigningIdentity();

					// Generate Keys and CSR
					let orgMSP = userCtx._mspId;
					let CryptoMaterial = await Crypto.generateKeysCSR(user, orgMSP);

					// Call reenroll in BE
					CryptoMaterial.enrollment = await ca.reenrollAppUser(CryptoMaterial.csr, userSigningIdentity, null);

					const x509 = Crypto.generateIdentity(CryptoMaterial);
					fs.writeFileSync(`wallet/${user}.id`, JSON.stringify(x509));

				} catch(e) {
					console.log(e);
					throw e;
				}
			}
			else if (mode === 'getdate') {
				console.log('Getting expiration date of user...');
				console.log('Example: node app.js getdate user0 lynkeus');
				let appUserId = args[1];

				res = await ca.getExpirationDate(appUserId);
				console.log('Max User Expiration Date: ', res);
			}
			else if (mode === 'revoke') {
				console.log('Revoking certificate');
				console.log('Example: node app.js revoke lynkeus certInPemFormat');

				let pemCert = args[1];
				let reason = 'why not';

				let res = await ca.revokeCertificate(pemCert, reason);
				console.log(res);
			}
			else if (mode === 'createuser') {
				let user = args[1];
				const userObj = {
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
					purposes: ['Marketing']
				};
				console.log('Submit CreateUser transaction...');
				await userContract.createUser(user, userObj);
			}
			else if (mode === 'getcertbyserial') {
				console.log('Getting certificate stats by serial number...');
				const serial = args[2];

				const response = await ca.getCertificateBySerial(serial);
				console.log(response);
			}
			else if (mode === 'deleteuser') {
				const user = args[1];
				console.log('Deleting user...');
				let res = await userContract.deleteUser(user, user);
				console.log(res);
			}
			else if (mode === 'deleteproduct') {
				const user = args[1];
				const productID = args[2];
				console.log('Deleting product...');
				let res = await dataContract.deleteProduct(user, productID);
				console.log(res);
			}
			else if (mode === 'getusers') {
				let res = await userContract.getUsers(client);
				console.log(util.inspect(res, false, null, true));
				console.log('Total: ', res.length);
			}
			else if (mode === 'getproduct') {
				let res = await dataContract.readProduct(client, args[1]);
				console.log(res);
			}
			else if (mode === 'getproducts') {
				let res = await dataContract.getProducts(client);
				console.log(util.inspect(res, false, null, true));
				console.log('Total: ', res.length);
			}
			else if (mode === 'getagreements') {
				let res = await agreementContract.getAgreements(client);
				console.log(res);
				console.log('Total: ', res.length);
			}
			else if (mode === 'getagreement') {
				console.log('Example: node app.js getagreement aggreementID');
				let agreementID = args[1];

				let res = await agreementContract.getAgreement(client, agreementID);
				console.log(res);
			}
			else if (mode === 'updateagreement') {
				console.log('Example: node app.js updateagreement aggreementID status');
				let agreementID = args[1];
				let status = 'Access';

				let res = await agreementContract.updateAgreement(client, agreementID, status);
				console.log(res);
			}
			else if (mode === 'printcert') {
				console.log(JSON.parse(fs.readFileSync(`wallet/${args[1]}.id`)).credentials.certificate);
			}
			else if (mode === 'gethistoryofproducttxs') {
				let productID = args[1];

				let transaction = {fcn: 'AgreementContract:GetTransactionHistoryOfProduct', args: [productID]};
				let res = await SignOffline.sendTransaction(client, transaction, channelID, chaincodeID);
				console.log(util.inspect(res, false, null, true));
			}
			else {
				console.log('Command not found.');
			}

			await offchainDB.disconnect();

		}
	} catch(e) {
		console.log(e);
		console.log('Process exits with error message: ', e.message);
		process.exit(1);
	}

}

main();

