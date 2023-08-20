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
import { ReenrollResponse, ICA } from './interfaces';
import * as Crypto from './Crypto';
import { getLogger } from './libUtil';
import { CACONFIG } from './Config'

import * as path from 'path';
import * as fs from 'fs';
import * as yaml from 'js-yaml';
require('dotenv').config();

/* Env */
const walletPath = path.join(CACONFIG.walletPath);
const ccpPath = path.resolve(CACONFIG.ccpPath);

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
	identityService: FabricCAServices.IdentityService;
	caMain: any;
	ca: any;
	currentCA: string;
	caData: ICA;
	type?: string;

	/**
	 * Construct a {@link CAServices} object.
	 *
	 * @param {ICA} caData - The CA Data
	 */
	constructor(caData: ICA) {
		if (!caData.orgName || !caData.caName || !caData.orgMSP) {
			throw new Error('Error creating CA. Missing parameters!')
		}
		
		this.caData = caData;
		this.orgName = caData.orgName;
		this.orgMSP = caData.orgMSP;
		this.registrarID = caData.registrarID
		this.ca = this.createCA()
		this.type = caData.type || 'main'
		this.identityService = this.ca.newIdentityService();
	}


	// useCA(currentCA: string) {
	// 	this.currentCA = currentCA;
	// 	this.ca = (currentCA == 'main' ? this.caMain : this.caUsers)
	// 	this.orgMSP = (currentCA == 'main' ? this.caMain : this.caUsers)
	// }

	/**
	 * Error handler for contract API
	 *
	 * @ignore
	 * @param {Error} e The error object
	 * @param {String} method The function's name
	 */
	private handleError(e: any, method: string): never {
		logger.error(`${method} - ${e.message}`);
		throw e;
	}

	/**
	 * Get identity from Wallet
	 *
	 * @param {String} userID The ID of the admin
	 * @returns {Object} The IdentityContext of the admin
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
			this.handleError(e, method);
		}
	}

	/**
	 * Creates CA instance based on existing ccp.yaml
	 * on local file system at path: ../ccp.yaml
	 *
	 * @returns {Object} The CA instances
	 */
	createCA(): FabricCAServices {
		const method = 'createCA';

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

			logger.debug(`${method} - loaded ca_${this.orgName}`);
			const tlsRootCert = fs.readFileSync(tlsPath, 'ascii');
			const tlsOptions: FabricCAServices.TLSOptions = {
				trustedRoots: <any>tlsRootCert,
				verify: true
			};

			// Create Identity Service
			const caName = `ca-${this.orgName}${this.type === 'users' ? '-users' : ''}`
			return new FabricCAServices(caURL, tlsOptions, caName);

		} catch (e: any) {
			this.handleError(e, method);
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

		try {

			// Role to check
			const checkRole = 'admin';

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Fetch the user identity from the CA
			const userIdentity = await this.identityService.getOne(appUserID, adminCtx as User)
			const status = userIdentity.result.type === checkRole; 

			return status;
		} catch (e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Fetch a user from orgUsersCa
	 *
	 * @param {String} appUserID The user name to check
	 * @returns {userIdentity} True if user is admin, else false
	 */	
	async getUser(appUserID: string): Promise<any> {
		const method = 'getUser'

		try {
			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Fetch the user identity from the CA
			const userIdentity = await this.identityService.getOne(appUserID, adminCtx as User)

			return userIdentity
		} catch(e: any) {
			this.handleError(e, method)
		}
	}

	/**
	 * Updates a user on the CA
	 *
	 * @param {String} appUserID The username to update
	 * @param {FabricCAServices.IIdentityRequest} identityRequest The identityRequest object to pass to the CA
	 * @returns {Bool} 0 on success, -1 on failure
	 */
	async updateUser(appUserID: string, identityRequest: FabricCAServices.IIdentityRequest): Promise<any> {
		const method = 'updateUser';

		try {
			logger.debug(`${method} - Updating user: ${appUserID}...`);

			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Update Identity
			return await this.identityService.update(appUserID, identityRequest, adminCtx as User);
		} catch (e: any) {
			this.handleError(e, method);
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
	async deleteUser(appUserID: string, force?: string): Promise<any> {
		const method = 'deleteUser';

		try {
			// Get Admin Context
			const adminCtx = await this.getIdentityContextFromWallet(this.registrarID);

			// Delete identity from CA
			return await this.identityService.delete(appUserID, adminCtx as User);
		} catch (e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Register a user to the organization's CA
	 *
	 * @param {String} appUserID	The user name to register
	 * @param {String} appUserRole 	The user's role to be registered
	 * @returns {any}    		Registration response
	 */
	async registerAppUser(appUserID: string, appUserRole: string, secret: string): Promise<any> {
		const method = 'registerAppUser';

		try {
			logger.debug(`${method} - Registering user: ${appUserID} to ${this.orgName}-users`);
			
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
			return await this.ca.register(registrationRequest, adminCtx);
		} catch (e: any) {
			this.handleError(e, method);
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

		try {

			if (csr) {
				logger.debug(`${method} - Enrolling user: ${appUserID} with CSR`);

				const enrollmentRequest: FabricCAServices.IEnrollmentRequest = {
					enrollmentID: appUserID,
					enrollmentSecret: secret,
					csr: csr
				}

				// Enroll to CA
				const enrollment = await this.ca.enroll(enrollmentRequest);

				logger.info(`${method} - User ${appUserID} enrolled successfully with CSR`);
				return enrollment;
			}
			else {

				const wallet = await Wallets.newFileSystemWallet(walletPath);

				// const userIdentity = await wallet.get(appUserID);
				// if (userIdentity) {
				// 	logger.warn(`${method} - User ${appUserID} crypto material already exists in wallet`);
				// 	return 0;
				// }

				logger.debug(`${method} - Enrolling user: ${appUserID} without CSR`);

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
					mspId: this.orgMSP,
					type: 'X.509',
				};

				logger.info(`${method} - User ${appUserID} enrolled successfully without CSR`);
				await wallet.put(appUserID, x509Identity);

				return x509Identity;
			}

		} catch (e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Import existing MSP to local Wallet folder
	 *
	 * @param {String} userID The user ID to import
	 * @param {String} importPath the MSP path
	 */
	async importMSP(userID: string, importPath: string = './identities') {
		const method = 'importMSP';

		try {
			logger.debug(`${method} - Importing MSP of user: ${userID}...`);

			// Create wallet
			const wallet = await Wallets.newFileSystemWallet(walletPath);

			// Import identities from org folders
			const certPath = path.resolve(`${importPath}`, `${userID}`, 'msp', 'signcerts', 'cert.pem');
			if (!fs.existsSync(certPath)) {
				throw new Error(`Public certificate path of ID: ${userID} of Org: ${this.orgMSP} not found at Path: ${certPath}`)
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
				mspId: `${this.orgMSP}`,
				type: 'X.509',
			};

			return await wallet.put(userID, x509Identity);

		} catch (e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Import existing MSP to local Wallet folder
	 *
	 * @param {String} userID The user ID to import
	 * @returns {Number} 0 for success, -1 for failure
	 */
	async exportMSP(userID: string): Promise<number> {
		const method = 'exportMSP';

		const mspPath = `./${userID}/msp`;
		const signcertsPath = `./${userID}/msp/signcerts`;
		const privatekeyPath = `./${userID}/msp/keystore`;

		try {
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

			return 0;
		} catch (e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Renrolls a user with the secret obtained from registration
	 *
	 * @param {String} csr The Certificate Signing Request
	 * @param {SigningIdentity} signingIdentity The Signing Identity Object
	 * @param {Object} attrReqs Attributes to add to the user
	 * @returns {Promise<ReenrollResponse>} Contains signCert and rootCert
	 */
	async reenrollAppUser(csr: string, signingIdentity: any, attrReqs: object = {}): Promise<ReenrollResponse> {
		const method = 'reenrollAppUser';

		try {
			let userID = (Crypto.decodeCertificate(signingIdentity._certificate)).subject.attributes[1].value
			logger.debug(`${method} - Reenrolling user: ${userID}`);

			// Identity
			const response = await this.ca._fabricCAClient.reenroll(csr, signingIdentity, attrReqs);

			logger.debug(`${method} - User: ${userID} reenrolled`);

			const reenrollResponse: ReenrollResponse = {
				// key: privateKey,
				certificate: Buffer.from(response.result.Cert, 'base64').toString(),
				rootCertificate: Buffer.from(response.result.ServerInfo.CAChain, 'base64').toString()
			};

			return reenrollResponse;
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Revoke a specific certificate of a user of OrgUsersCA
	 *
	 * @param {String} certificate The certificate in PEM format
	 * @param {String} reason Reason for revoking the certificate
	 * @returns {Object} Response of CA
	 * */
	async revokeCertificate(certificate: string, reason: string): Promise<any> {
		const method = 'revokeCertificate';

		try {
			logger.debug(`${method} - Revoking certificate ${certificate} ${reason}`);

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
					// let req = {
					// 	message: certificate,
					// 	revoked: true
					// }
					// await this.peer.triggerCRLUpdate(req).then((response: any) => {
					// 	if (response.status == 200) {
					// 		logger.info('${} - Channel config updated', method, response);
					// 	} else {
					// 		logger.warn('${} - Failed to update channel configuration', method)
					// 	}
					// });
				}

				return response;
			})

			logger.debug(`${method} - CA Response: ${response}`);
			// this.addRevokedCertificate(certificate)
			
			return response;
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	/**
	 * Fetch a certificate by serial number from CA
	 *
	 * @param {String} serial The serial number of cert
	 * @returns {String} The certificate in PEM format
	 * */
	async getCertificateBySerial(serial: string): Promise<string> {
		const method = 'getCertificateBySerial';

		try {
			logger.debug(`${method} - Getting certificate by serial number: ${serial}`);

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
			logger.debug(`${method} - \nSerial: ${result.serial} \nAKI: ${result.aki}`);

			return cert;
		} catch(e: any) {
			this.handleError(e, method);
		}

	}

	/**
	 * Get a user's max expiration date among their certificates
	 *
	 * @param {String} appUserID The user's ID
	 * @returns {ISODate} The max expiration date among all the certificates
	 */
	async getExpirationDate(appUserID: string): Promise<Date> {
		const method = 'getExpirationDate';

		try {
			logger.debug(`${method} - Getting expiration date of $appUserID{}`);

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
			logger.debug(`${method} - Number of certificates: ${certs.length}`);

			// Find max expiration date of all certificates of user
			let maxDate = new Date();
			let expDate;
			for (let cert of certs) {
				logger.debug(`${method} - Cert: ${cert.PEM}`)
				expDate = Crypto.getCertExpirationDate(cert.PEM);
				if (expDate.getTime() > maxDate.getTime()) {
					maxDate = expDate;
				}
					logger.debug(`${method} - Max Expiration date: ${expDate}`);
			}

			return maxDate;
		} catch(e: any) {
			this.handleError(e, method);
		}
	}

	setRegistrar(registrarID: string) {
		this.registrarID = registrarID;
	}
}

export default CAServices