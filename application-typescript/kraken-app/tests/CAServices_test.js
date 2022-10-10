/*
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * Author: Alexandros Tragkas
 */

'use strict';

const { Wallets } = require('fabric-network');
const assert = require('assert');
const { CAServices, Crypto } = require('../index');
const { sleep } = require('../dist/libUtil');
const fs = require('fs')
require('dotenv').config();
require('chai')
	.use(require('chai-as-promised'))
	.should();

const test_data = require('./test_data');
const registrar = process.env.REGISTRAR;
const appUserID = process.env.USERNAME;

let ca
if (registrar.includes('lynkeus')) {
	ca = new CAServices('lynkeus', 'ca-lynkeus', 'LynkeusMSP', registrar);
} else if (registrar.includes('tex')) {
	ca = new CAServices('tex', 'ca-tex', 'TexMSP', registrar);
} else {
	throw new Error('No Registrar set. Please set registrar in .env')
}

let secret = 'userSecret';
let result;
let appUserRole = 'client';
let cert_to_revoke;

describe('==== Lib CAServices ====', async () => {

	context('Filesystem Operations', async () => {

		/* Import admin's MSP to local Wallet */
		it('Should ImportMSP', async () => {
			result = await ca.importMSP(registrar, true);
			assert(result === 0);
		});

		it('Should ExportMSP', async () => {
			result = await ca.exportMSP(registrar);
			assert(result === 0);
		});

	});

	context('Enrollment Lifecycle ', () => {

			it('Should Register User', async () => {
				for (let u of test_data.userIDs) {
					console.log('user: ' + u)
					result = await ca.registerAppUser(u, appUserRole, secret);
					// assert(result === 0);
				}
			});

			it('Should Enroll User NO CSR', async () => {
				for (let u of test_data.userIDs) {
					result = await ca.enrollAppUser(u, secret);
					assert(result === 0);
				}
			});

		it('Updates User (Role)', async () => {
			let mods = {
				enrollmentID: appUserID,
				type: 'client',
				affiliation: '',
				maxEnrollments: 1e3,
				attrs: '',
				// caname: ''
			};
			result = await ca.updateUser(appUserID, mods);
			assert(result === 0);
			await sleep(1000);
			result = await ca.getUser(appUserID);
			assert(result.result.max_enrollments === 1e3);
		});

		// DELETE DOES NOT WORK, FABRIC BUG?
		// it('Delete User', async () => {
		// 	result = await ca.deleteUser(appUserID, false);
		// 	assert(result === 0);
		// });

		// it('Should Register User 2nd Time', async () => {
		// 	result = await ca.registerAppUser(appUserID, appUserRole, secret);
		// 	assert(result === 0);
		// });

		it('Should Enroll User CSR', async () => {
			// Generate Keys and X509 CSR Request
			let cryptoMaterial = await Crypto.generateKeysCSR(appUserID, ca.orgUsersMSP);
			let csr_request = cryptoMaterial.csr;

			// Enroll User with CSR
			cryptoMaterial.enrollment = await ca.enrollAppUser(appUserID, secret, csr_request);
			assert(Crypto.isValidIdentity(Crypto.generateIdentity(cryptoMaterial)) === true);

			const x509 = Crypto.generateIdentity(cryptoMaterial);
			fs.writeFileSync(`./wallet/${appUserID}.id`, JSON.stringify(x509));
			await sleep(1000)
		});

		it('Should Reenroll User CSR', async () => {
			// Generate Keys and X509 CSR Request
			let cryptoMaterial = await Crypto.generateKeysCSR(appUserID, ca.orgUsersMSP);
			let csr_request = cryptoMaterial.csr;
			let userCtx = await ca.getIdentityContextFromWallet(appUserID);
			let userSigningIdentity = userCtx.getSigningIdentity();
			cert_to_revoke = userSigningIdentity._certificate

			// Enroll User with CSR
			cryptoMaterial.enrollment = await ca.reenrollAppUser(csr_request, userSigningIdentity, null);
			assert(Crypto.isValidIdentity(Crypto.generateIdentity(cryptoMaterial)) === true);
			
			const x509 = Crypto.generateIdentity(cryptoMaterial);
			fs.writeFileSync(`./wallet/${appUserID}.id`, JSON.stringify(x509));
			await sleep(1000)
		});

	});

	context('Revocations', async () => {
		it ('Should revoke Certificate', async () => {
			let res = await ca.revokeCertificate(cert_to_revoke, 'Testing Purposes');
			assert(res.success === true)
		})

		it('Should Reenroll User CSR After Cert Revocation', async () => {
			// Generate Keys and X509 CSR Request
			let cryptoMaterial = await Crypto.generateKeysCSR(appUserID, ca.orgUsersMSP);
			let csr_request = cryptoMaterial.csr;
			let userCtx = await ca.getIdentityContextFromWallet(appUserID);
			let userSigningIdentity = userCtx.getSigningIdentity();
			cert_to_revoke = userSigningIdentity._certificate

			// Enroll User with CSR
			cryptoMaterial.enrollment = await ca.reenrollAppUser(csr_request, userSigningIdentity, null);
			assert(Crypto.isValidIdentity(Crypto.generateIdentity(cryptoMaterial)) === true);
			
			const x509 = Crypto.generateIdentity(cryptoMaterial);
			fs.writeFileSync(`./wallet/${appUserID}.id`, JSON.stringify(x509));
			await sleep(1000)
		});
	});

	context('Various CA Operations', async () => {
		it('Check admin role', async () => {
			result = await ca.isAdmin(appUserID);
			assert(result === false);
			// result = await ca.isAdmin(registrar);
			// assert(result === true);
		});
	});

});