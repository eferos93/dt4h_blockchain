/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file API for CA and MSP related functionality
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'CAServices';

/* Dependencies */
import { Wallets, X509Identity } from 'fabric-network';
import FabricCAServices from 'fabric-ca-client';
import { User } from 'fabric-common';
import { ReenrollResponse } from './interfaces';
import * as Crypto from './libCrypto';
// import { GrpcClient } from './libGrpc';
import { getLogger } from './libUtil';

import * as path from 'path';
import * as fs from 'fs';
import * as process from 'process';
import * as yaml from 'js-yaml';
require('dotenv').config();

/* Env */
const walletPath = path.join(process.env.WALLET_PATH!);
const ccpPath = path.resolve(process.env.CCP_PATH!);
const revokedCertificates = path.resolve(process.env.REVOKED_CERTS_PATH!)

/* Logging */
const logger = getLogger(TYPE);

/**
 * @classdesc API Implementation for Fabric CA Services
 * 
 * @class
 */
export class CAServices {

	orgName: string;
	orgMSP: string;
	registrarID: string;
	orgUsersMSP: string;
	identityService: FabricCAServices.IdentityService;
	ca: any;
	peer: any;

	/**
	 * Construct a {@link CAServices}  object.
	 *
	 * @param {String} orgName - The organization's name (non capitalized)
	 * @param {String} caName - The organization's CA Server Name
	 * @param {String} orgMSP - The organization's MSP ID
	 * @param {String} registrarID - The organization's registrar (Admin performing the operations)
	 * @param {String} endpoint - The organization's peer endpoint for RPC
	 */
	constructor(orgName: string, caName: string, orgMSP: string, registrarID: string, endpoint?: string) {
		if (!orgName || !caName || !orgMSP) {
			throw new Error('Error creating CA. Missing parameters!')
		}

		if (!endpoint) {
			logger.warn('constructor - No peer endpoint given')
			endpoint = 'localhost:4001'
		}

		this.orgName = orgName;
		this.orgMSP = orgMSP;
		this.ca = this.createCA()
		this.identityService = this.ca.newIdentityService();
		this.registrarID = registrarID
		this.orgUsersMSP = orgMSP.split("MSP")[0] + 'UsersMSP'
		// this.peer = new GrpcClient(endpoint);
	}

	/**
	 * Error handler for contract API
	 *
	 * @ignore
	 * @param {Error} e The error object
	 * @param {String} method The function's name
	 */
	private handleError(e: any, method: string) {
		logger.error('%s - %s', method, e.message);
		return e;
	}

	/**
	 * Get identity from Wallet
	 *
	 * @param {String} userID The ID of the user/admin
	 * @returns {Object} The IdentityContext of the user/admin
	 * */
	async getIdentityContextFromWallet(userID: string): Promise<User | null> {
		const method = 'getIdentityContextFromWallet';

		// Create wallet instance
		const wallet = await Wallets.newFileSystemWallet(walletPath);

		try {
			// Get Admin
			const userIdentity = await wallet.get(userID);
			if (!userIdentity) {
				return null
			}

			// Get Admin Context
			const provider = wallet.getProviderRegistry().getProvider(userIdentity.type);
			const userContext = await provider.getUserContext(userIdentity, userID);

			return userContext;
		} catch(e: any) {
			// logger.warn('%s - user %s not found in wallet', method, userID)
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Creates CA instance based on existing ccp.yaml
	 * on local file system at path: ../ccp.yaml
	 *
	 * @returns {Object} The CA instance
	 */
	createCA(): FabricCAServices {
		const method = 'createCA';
		logger.start(method);

		try {
			// Load the network config
			let fileExists = fs.existsSync(ccpPath);
			if (!fileExists) {
				throw new Error(`Connection profile path not found at file: ${ccpPath}`);
			}

			// Load .yaml config
			const ccpYaml = fs.readFileSync(ccpPath);
			const ccp = yaml.load(ccpYaml.toString()) as any;

			// Set CA and use TLS
			const caURL = ccp.certificateAuthorities[`ca_${this.orgName}`].url;
			const tlsRelPath = ccp.certificateAuthorities[`ca_${this.orgName}`].tlsCACerts.path;
			const tlsPath = path.resolve(tlsRelPath);
			fileExists = fs.existsSync(tlsPath);
			if (!fileExists) {
				throw new Error(`TLS Certificate for Org: ${this.orgName} not found at file: ${tlsPath}`);
			}

			logger.debug(`%s - loaded ca_${this.orgName}`, method);
			const tlsRootCert = fs.readFileSync(tlsPath, 'ascii');
			const tlsOptions: FabricCAServices.TLSOptions = {
				trustedRoots: <any>tlsRootCert,
				verify: true
			};

			// Create Identity Service
			const ca = new FabricCAServices(caURL, tlsOptions, `ca-${this.orgName}-users`);
			logger.debug('%s - created CA instance', method);

			return ca;
		} catch (e: any) {
			this.handleError(e, method);
			throw e;
		}

	}

	/**
	 * Checks if a user is registered as admin on the org's CA
	 *
	 * @param {String} appUserID The user name to check
	 * @returns {Bool} True if user is admin, else false
	 */
	async isAdmin(appUserID: string): Promise<boolean> {
		const method = 'isAdmin';
		logger.start(method);

		try {
			logger.debug(`%s - Checking admin status of ${appUserID}...`, method);

			// Role to check
			const checkRole = 'admin';

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Fetch the user identity from the CA
			const userIdentity = await this.identityService.getOne(appUserID, adminCtx as User)
			const status = userIdentity.result.type === checkRole; 

			logger.info('%s - Admin status of %s: %s', method, appUserID, status);
			return status;
		} catch (e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Fetch a user from orgUsersCa
	 *
	 * @param {String} appUserID The user name to check
	 * @returns {userIdentity} True if user is admin, else false
	 */	
	async getUser(appUserID: string) {
		const method = 'getUser'
		// logger.start(method)

		try {
			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Fetch the user identity from the CA
			const userIdentity = await this.identityService.getOne(appUserID, adminCtx as User)

			return userIdentity
		} catch(e: any) {
			this.handleError(e, method)
			// throw e;
		}
	}
	/**
	 * Updates a user on the CA
	 *
	 * @param {String} appUserID The username to update
	 * @param {FabricCAServices.IIdentityRequest} identityRequest The identityRequest object to pass to the CA
	 * @returns {Bool} 0 on success, -1 on failure
	 */
	async updateUser(appUserID: string, identityRequest: FabricCAServices.IIdentityRequest) {
		const method = 'updateUser';
		logger.start(method);

		try {
			logger.debug(`%s - Updating user: ${appUserID}...`, method);

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Update Identity
			await this.identityService.update(appUserID, identityRequest, adminCtx as User);

			logger.info('%s - User %s updated successfully', method, appUserID);

			// Return success
			return 0;
		} catch (e: any) {
			this.handleError(e, method);
			return -1;
		}
	}

	/**
	 * DOES NOT WORK, FABRIC BUG?
	 * Removes a user from the CA
	 *
	 * @param {String} appUserID The user's ID to be removed
	 * @param {Bool} force True if admin can remove self
	 * @returns {Number} 0 on success, -1 on failure
	 */
	async deleteUser(appUserID: string, force?: string) {
		const method = 'deleteUser';
		logger.start(method);

		try {
			logger.debug('%s - Deleting user: %s', method, appUserID);

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Delete identity from CA
			await this.identityService.delete(appUserID, adminCtx as User);

			logger.info('%s - User %s deleted successfully', method, appUserID);

			return 0;
		} catch (e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Register a user to the organization's CA
	 *
	 * @param {String} appUserID	The user name to register
	 * @param {String} appUserRole 	The user's role to be registered
	 * @returns {Number}    		0 for Success, -1 on error
	 */
	async registerAppUser(appUserID: string, appUserRole: string, secret: string): Promise<number> {
		const method = 'registerAppUser';
		logger.start(method);
		logger.debug('%s - ', method);

		try {
			logger.debug('%s - Registering user: %s to %s-users', method, appUserID, this.orgName);
			
			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);
			const registrationRequest: FabricCAServices.IRegisterRequest = {
				enrollmentID: appUserID,
				enrollmentSecret: secret,
				role: appUserRole,
				maxEnrollments: -1,
				affiliation: ''
			}

			// Register
			await this.ca.register(registrationRequest, adminCtx);

			logger.info('%s - User %s registered succesfully', method, appUserID);

			// Return null for success
			return 0;
		} catch (e: any) {
			this.handleError(e, method);
			return -1;
		}
	}

	/**
	 * Enrolls a user with the secret obtained from registration
	 *
	 * @param {String} appUserID 	The user's id to enroll
	 * @param {String} secret 		The secret to use on enrollment
	 * @param {String} csr 			The Certificate Signing Request (CSR) for offline key gen
	 * @returns {Number | FabricCAServices.IEnrollResponse}  0 on success, -1 on failure
	 */
	async enrollAppUser(appUserID: string, secret: string, csr?: string): Promise<X509Identity | FabricCAServices.IEnrollResponse> {
		const method = 'enrollAppUser';
		logger.start(method);
		logger.debug('%s - ', method);

		try {

			if (csr) {
				logger.debug('%s - Enrolling user: %s with CSR', method, appUserID);

				const enrollmentRequest: FabricCAServices.IEnrollmentRequest = {
					enrollmentID: appUserID,
					enrollmentSecret: secret,
					csr: csr
				}

				// Enroll to CA
				const enrollment = await this.ca.enroll(enrollmentRequest);

				logger.info('%s - User %s enrolled successfully with CSR', method, appUserID);
				return enrollment;
			}
			else {

				const wallet = await Wallets.newFileSystemWallet(walletPath);

				// const userIdentity = await wallet.get(appUserID);
				// if (userIdentity) {
				// 	logger.warn('%s - User %s crypto material already exists in wallet', method, appUserID);
				// 	return 0;
				// }

				logger.debug('%s - Enrolling user: %s without CSR', method, appUserID);

				// Enroll to CA
				const enrollmentRequest: FabricCAServices.IEnrollmentRequest = {
					enrollmentID: appUserID,
					enrollmentSecret: secret
				}

				const enrollment = await this.ca.enroll(enrollmentRequest);

				// Put identity to Wallet
				const x509Identity: X509Identity = {
					credentials: {
						certificate: enrollment.certificate,
						privateKey: enrollment.key.toBytes(),
					},
					mspId: `${this.orgUsersMSP}`,
					type: 'X.509',
				};

				logger.info('%s - User %s enrolled successfully without CSR', method, appUserID);
				await wallet.put(appUserID, x509Identity);

				return x509Identity;
			}

		} catch (e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Import existing MSP to local Wallet folder
	 *
	 * @param {String} userID The user ID to import
	 * @returns {Number} 0 for success, -1 for failure
	 */
	async importMSP(userID: string, usersMSP: boolean) {
		const method = 'importMSP';
		logger.start(method);

		try {
			logger.debug(`%s - Importing MSP of user: ${userID}...`, method);

			// Create wallet
			const wallet = await Wallets.newFileSystemWallet(walletPath);
			const importPath = './identities';

			let msp = usersMSP ? this.orgUsersMSP : this.orgMSP
			// const userIdentity = await wallet.get(userID);
			// if (userIdentity) {
			// 	logger.warn('%s - User already exists.', method);
			// 	return 0;
			// }

			// Import identities from org folders
			const certPath = path.resolve(`${importPath}`, `${userID}`, 'msp', 'signcerts', 'cert.pem');
			if (!fs.existsSync(certPath)) {
				throw new Error(`Public certificate path of ID: ${userID} of Org: ${msp} not found at Path: ${certPath}`)
			}

			// User is already enrolled from CLI
			const keyPath = path.resolve(`${importPath}`, `${userID}`, 'msp', 'keystore', 'key.pem');
			const cert = fs.readFileSync(certPath, 'ascii');
			const key = fs.readFileSync(keyPath, 'ascii');


			let x509Identity: X509Identity = {
				credentials: {
					certificate: cert,
					privateKey: key,
				},
				mspId: `${msp}`,
				type: 'X.509',
			};

			await wallet.put(userID, x509Identity);
			logger.info('%s - User %s imported successfully', method, userID);
			return 0;

		} catch (e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Import existing MSP to local Wallet folder
	 *
	 * @param {String} userID The user ID to import
	 * @returns {Number} 0 for success, -1 for failure
	 */
	async exportMSP(userID: string) {
		const method = 'exportMSP';
		logger.start(method);

		const mspPath = `./${userID}/msp`;
		const signcertsPath = `./${userID}/msp/signcerts`;
		const privatekeyPath = `./${userID}/msp/keystore`;

		try {
			logger.debug(`%s - Exporting MSP of user: ${userID}`, method);

			// Create wallet
			const wallet = await Wallets.newFileSystemWallet(walletPath);
			const user = <X509Identity> await wallet.get(userID);

			let dirExists = fs.existsSync(mspPath);
			if (!dirExists) {
				fs.mkdirSync(mspPath, { recursive: true });
				fs.mkdirSync(signcertsPath, { recursive: true });
				fs.mkdirSync(privatekeyPath, { recursive: true });
			}

			fs.writeFileSync(`${signcertsPath}/cert.pem`, user.credentials.certificate);
			fs.writeFileSync(`${privatekeyPath}/key.pem`, user.credentials.privateKey);

			logger.info('%s - Exported MSP of %s', method, userID);
			return 0;
		} catch (e: any) {
			this.handleError(e, method);
			// fs.rmdirSync(mspPath);
			return -1;
		}
	}

	/**
	 * Renrolls a user with the secret obtained from registration
	 *
	 * @param {String} csr The Certificate Signing Request
	 * @param {SigningIdentity} signingIdentity The Signing Identity Object
	 * @param {Object} attrReqs Attributes to add to the user
	 * @returns {Object} Contains signCert and rootCert
	 */
	async reenrollAppUser(csr: string, signingIdentity: any, attrReqs = null): Promise<ReenrollResponse> {
		const method = 'reenrollAppUser';
		logger.start(method);

		try {
			let userID = (Crypto.decodeCertificate(signingIdentity._certificate)).subject.attributes[1].value
			logger.info('%s - Reenrolling user: %s', method, userID);

			// Identity
			const response = await this.ca._fabricCAClient.reenroll(csr, signingIdentity, attrReqs);

			logger.info('%s - User: %s reenrolled', method, userID);

			const reenrollResponse: ReenrollResponse = {
				// key: privateKey,
				certificate: Buffer.from(response.result.Cert, 'base64').toString(),
				rootCertificate: Buffer.from(response.result.ServerInfo.CAChain, 'base64').toString()
			};

			return reenrollResponse;
		} catch(e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Revoke a specific certificate of a user of OrgUsersCA
	 *
	 * @param {String} certificate The certificate in PEM format
	 * @param {String} reason Reason for revoking the certificate
	 * @returns {Object} Response of CA
	 * */
	async revokeCertificate(certificate: string, reason: string) {
		const method = 'revokeCertificate';
		logger.start(method);

		try {
			logger.info('%s - Revoking certificate...', method);

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Get Serial and AKI
			const pemContext = Crypto.getCertSerialAndAKI(certificate);

			// Create revoke request
			const request = {
				// ...getCertSerialAndAKI(certificate),
				serial: pemContext.serial,
				aki: pemContext.aki,
				reason,
				gencrl: true
			};

			const response = <any>await this.ca.revoke(request, adminCtx).then(async (response: any) => {
				if (response.success) {
					let req = {
						message: certificate,
						revoked: true
					}
					// await this.peer.triggerCRLUpdate(req).then((response: any) => {
					// 	if (response.status == 200) {
					// 		logger.info('%s - Channel config updated', method, response);
					// 	} else {
					// 		logger.warn('%s - Failed to update channel configuration', method)
					// 	}
					// });
				}

				return response;
			})

			logger.debug('%s - CA Response: ', method, response);
			// this.addRevokedCertificate(certificate)
			
			return response;
		} catch(e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Fetch a certificate by serial number from CA
	 *
	 * @param {String} serial The serial number of cert
	 * @returns {String} The certificate in PEM format
	 * */
	async getCertificateBySerial(serial: string) {
		const method = 'getCertificateBySerial';
		logger.start(method);

		try {
			logger.info('%s - Getting certificate by serial number: %s', method, serial);

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Get certificate Service Instance from CA
			const certificateService = this.ca.newCertificateService();

			// Request certificates of user to CA
			const request = {
				ca: `ca-${this.orgName}-users`,
				serial: serial
			};

			// Fetch response
			const response = await certificateService.getCertificates(request, adminCtx);

			// Get certs from response
			const cert = response.result.certs[0];
			const PEM = cert[Object.keys(cert)[0]];

			const result = Crypto.getCertSerialAndAKI(PEM);
			logger.info('%s - \nSerial: %s \nAKI: %s', method, result.serial, result.aki);

			return cert;
		} catch(e: any) {
			this.handleError(e, method);
			throw e;
		}

	}

	/**
	 * Get a user's max expiration date among their certificates
	 *
	 * @param {String} appUserID The user's ID
	 * @returns {ISODate} The max expiration date among all the certificates
	 */
	async getExpirationDate(appUserID: string) {
		const method = 'getExpirationDate';
		logger.start(method);

		try {
			logger.info('%s - Getting expiration date of %s', method, appUserID);

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Get certificate Service Instance from CA
			const certificateService = this.ca.newCertificateService();

			// Request certificates of user to CA
			const request = {
				id: appUserID,
				ca: `ca-${this.orgName}-users`,
				notrevoked: true,
				notexpired: true
			};

			// Fetch response
			const response = await certificateService.getCertificates(request, adminCtx);

			// Get certs from response
			const certs = response.result.certs;
			logger.debug('%s - Number of certificates: %s', method, certs.length);

			// Find max expiration date of all certificates of user
			let maxDate = new Date();
			let expDate;
			for (let cert of certs) {
				logger.debug('%s - Cert: \n', method, cert.PEM)
				expDate = Crypto.getCertExpirationDate(cert.PEM);
				if (expDate.getTime() > maxDate.getTime()) {
					maxDate = expDate;
				}
					logger.debug('%s - Max Expiration date: ', method, expDate);
			}

			return maxDate;
		} catch(e: any) {
			this.handleError(e, method);
			throw e;
		}
	}

	/**
	 * Add a revoked certificate to a local file
	 * 
	 * @param {String} certificate A PEM encoded certificate
	 */
	// addRevokedCertificate(certificate: string) {
	// 	const method = 'addRevokedCertificate'
	// 	try {
		
	// 		fs.readFile(revokedCertificates, function (err: any, data: any) {
	// 			let jsonData = JSON.parse(data);
	// 			jsonData.revokedCerts.push(certificate);    
	// 			fs.writeFile(revokedCertificates, JSON.stringify(jsonData), function(err: any){
	// 				if (err) throw err;
	// 				logger.debug('%s - cert appended to json file', method);
	// 				console.log('good');
	// 			});
	// 		})
	// 	}
	// 	catch(e: any) {
	// 		this.handleError(e, method);
	// 		throw e;
	// 	}

	// }

	setRegistrar(registrarID: string) {
		this.registrarID = registrarID;
	}
}

