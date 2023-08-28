/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file Implementation of Crypto related functionalities
 * @module libCrypto
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'Crypto';

/* Dependencies */
import { CertSerialAndAki, EX509Identity, CryptoMaterial, IEnrollResponse, IClient } from './interfaces'
import { getLogger, toBuffer } from './libUtil'
import Connection from './Connection';

import { KeyObject, X509Certificate, generateKeyPair } from 'crypto';
import { Certificate } from '@fidm/x509';
import * as jsrsasign from 'jsrsasign';
const asn1 = jsrsasign.KJUR.asn1;


/* Logging */
const logger = getLogger(TYPE);

/* Crypto specifics */
const CRYPTO_ALGORITHM = 'ec';
const KEY_OPTIONS = {
	namedCurve: 'prime256v1',   // Options
	publicKeyEncoding: {
		type: 'spki',
		format: 'pem'
	},
	privateKeyEncoding: {
		type: 'pkcs8',
		format: 'pem'
	}
};

export async function isValidIdentity(cryptoMaterial: CryptoMaterial) {
	const method = 'isValidIdentity'
	const testMessage = new Uint8Array(Buffer.from("Hello, World!"));

	try {
		const x509Identity = generateIdentity(cryptoMaterial)
		const signer = await Connection.newSigner({ x509Identity })
		if (signer) {
			const sign = await signer(testMessage)
			return (sign?.length > 0)		
		} else {
			return undefined
		}
	} catch(e: any){
		logger.error(`${method} - ${e.message}`)
		return false
	}
}

// export function privateKeyPEMtoRaw(privateKeyPEM: X509Certificate) {
// 	// return key.replace('-----BEGIN PRIVATE KEY-----', "").replace('-----END PRIVATE KEY-----').trim()
// 	var cert = forge.pki.certificateFromPem(privateKeyPEM); 
// 	var pem = 
// 	forge.pki.publicKeyToPem(cert.publicKey)
// }

/**
 * Verify the validity of an x509 certificate
 * 
 * @param {String} certificate PEM encoded x509 Certificate
 * @returns {Bool} 
 * */
export function isValidX509(certificate: string) {
	const x509 = new X509Certificate(certificate)
	return x509.verify(x509.publicKey)
}

/**
 * Generate Identity Object of user
 *
 * @param {CryptoMaterial} CryptoMaterial Contains the user's crypto material and csr
 * @returns {EX509Identity} An identity object as specified by Fabric Node SDK
 */
export function generateIdentity(cryptoMaterial: CryptoMaterial): EX509Identity {
	const method = 'generateIdentity';

	const identity: EX509Identity = {
		credentials: {
			certificate: cryptoMaterial.enrollment.certificate,
			privateKey: cryptoMaterial.privateKey.toString()
		},
		mspId: cryptoMaterial.mspId,
		type: 'X.509',
		version: 1
	};

	logger.debug(`${method} - Identity cert: ${identity.credentials.certificate}`);
	return identity;
}

/**
 * Generate key pair and CSR
 *
 * @param {string} userID The enrollment ID
 * @param {string} orgMSP The organization's mspID
 * @returns {CryptoMaterial} Contains keys and csr
 */
export async function generateKeysCSR(userID: string, orgMSP: string): Promise<CryptoMaterial> {
	const method = 'generateKeysCSR';
	logger.debug(`${method} - Generating Crypto Material for user ${userID}`);

	let csrPem: string;

	return new Promise(function(resolve, reject) {
		try {
			// Generate key pair
			// let keys = forge.pki.rsa.generateKeyPair(2048);
			generateKeyPair(CRYPTO_ALGORITHM, KEY_OPTIONS, function(err, publicKey, privateKey) {
				if (err) {
					throw err;
				}

				logger.debug(`${method} - public Key: ${publicKey}`);

				try {
					const subjectDN = 'CN=' + userID;
					const csr = new asn1.csr.CertificationRequest({
						subject: { str: asn1.x509.X500Name.ldapToOneline(subjectDN) },
						sbjpubkey: publicKey.toString(),
						sigalg: 'SHA256withECDSA',
						sbjprvkey: privateKey.toString(),
					});

					// sign certification request
					csr.sign();

					// convert certification request to PEM-format
					csrPem = csr.getPEM();

					const result: CryptoMaterial = {
						mspId: orgMSP,
						subjectDN: subjectDN,
						csr: csrPem,
						privateKey: privateKey as KeyObject,
						publicKey: publicKey as KeyObject,
						enrollment: {} as IEnrollResponse
					};

					resolve(result);
				} catch (e: any) {
					logger.error(`${method} - ${e.message}`);
					reject(e);
				}
			});
		} catch (e: any) {
			logger.error(`${method} - ${e.message}`);
			// throw e;
			reject(e)
		}
	});
}

/**
 * Decode a PEM Certificate
 * 
 * @returns {Object} The Certificate in JSON
 * */
export function decodeCertificate(certificate: string): any {
	const method = 'decodeCertificate'
	return Certificate.fromPEM(toBuffer(certificate));
}

export function getCertSerialAndAKI(certificate: string): CertSerialAndAki {
	const method = 'getCertSerialAndAuthorityNumber';

	const certJSON = decodeCertificate(certificate)
	return {
		serial: certJSON.serialNumber,
		aki: certJSON.authorityKeyIdentifier
	}
}

export function getCertExpirationDate(certificate: string): Date {
	const method = 'getCertExpirationDate';

	const certJSON = decodeCertificate(certificate)
	return certJSON.validTo;
}
