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
import { CertSerialAndAki, EX509Identity, CryptoMaterial, IEnrollResponse } from './interfaces'
import { getLogger, toBuffer } from './libUtil'

import { KeyObject, X509Certificate, generateKeyPair } from 'crypto';
import { Certificate } from '@fidm/x509';
import * as jsrsasign from 'jsrsasign';
const asn1 = jsrsasign.KJUR.asn1;

import { signTransaction } from './libSignOffline'

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

export function isValidIdentity(signerX509Identity: EX509Identity) {
	const method = 'verifyIdentity'

	try {
		signTransaction(signerX509Identity, 'a message to sign')
		return true
	} catch(e: any){
		logger.error('%s - %s', method, e.message)
		return false
	}
	// let verify = crypto.createVerify('sha256');
	// let data = "Test data for signature verification"
	// let signature = getSignatureToVerify(data);
	// let sign = crypto.createSign(ALGORITHM);
	// sign.update(data);
	// let signature = sign.sign(privateKey, SIGNATURE_FORMAT);
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
	logger.start(method);

	const identity: EX509Identity = {
		credentials: {
			certificate: cryptoMaterial.enrollment.certificate,
			privateKey: cryptoMaterial.privateKey.toString()
		},
		mspId: cryptoMaterial.mspId,
		type: 'X.509',
		version: 1
	};

	logger.debug('%s - Identity cert: ', method, identity.credentials.certificate);
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
	logger.start(method);
	logger.info('%s - Generating Crypto Material for user', method, userID);

	let csrPem;

	return new Promise(function(resolve, reject) {
		try {
			// Generate key pair
			// let keys = forge.pki.rsa.generateKeyPair(2048);
			generateKeyPair(CRYPTO_ALGORITHM, KEY_OPTIONS, function(err, publicKey, privateKey) {
				if (err) {
					throw err;
				}

				logger.debug('%s - public Key: ', method, publicKey);

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

					logger.debug('%s - CSR PEM: ', method, csrPem);
					resolve(result);
				} catch (e: any) {
					logger.error('%s - ', method, e.message);
					reject(e);
				}
			});
		} catch (e: any) {
			logger.error('%s - ', method, e.message);
			throw e;
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
	// logger.start(method);

	const certJSON = decodeCertificate(certificate)
	return {
		serial: certJSON.serialNumber,
		aki: certJSON.authorityKeyIdentifier
	}
}

export function getCertExpirationDate(certificate: string): Date {
	const method = 'getCertExpirationDate';
	// logger.start(method);

	const certJSON = decodeCertificate(certificate)
	return certJSON.validTo;
}
