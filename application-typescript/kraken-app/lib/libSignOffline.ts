/**
 * Copyright Lynkeus 2021. All Rights Reserved.
 *
 * @file Implementation of offline transaction signing
 * @module libSignOffline
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'SignOffline';

/* Dependencies */
import { Client, User, IdentityContext, Endorsement, Channel, Commit } from 'fabric-common';
import { Wallets } from 'fabric-network';
import * as dotenv from "dotenv";
import * as crypto from 'crypto';
import * as util from 'util';
import * as path from 'path';

const elliptic = require('elliptic');
const { KEYUTIL } = require('jsrsasign');
dotenv.config({ path: __dirname + '/.env' });

/* Local Dependencies */
import { Transaction, Signer, ProposalSendRequest, EX509Identity } from './interfaces'
import * as Util from './libUtil';


const walletPath: string = path.join(process.env.WALLET_PATH!);
const logger = Util.getLogger(TYPE);
const clientID: string = process.env.CLIENT!;
// const revokedCertificates: string = path.resolve(process.env.REVOKED_CERTS_PATH!)

// interface Signer
// interface SignatureHeader
// interface Identity

// interface SignatureHeaderBuffer {
// 	nonce: number
// }

function _preventMalleability(sig: any) {
	const curve = elliptic.curves.p256
	const halfOrder = curve.n.shrn(1);
	if (sig.s.cmp(halfOrder) === 1) {
		const bigNum = curve.n;
		sig.s = bigNum.sub(sig.s);
	}
	return sig;
}

function getValidEndorsementResponse(endorsementResponses: any) {
	return endorsementResponses.find((endorsementResponse: any) => endorsementResponse.endorsement);
}

function newEndorsementError(proposalResponse: any) {
	let _a, _b;
	const errorInfos: any[] = [];
	for (const error of proposalResponse.errors) {
		const errorInfo = {
			peer: (_a = error === null || error === void 0 ? void 0 : error.connection) === null || _a === void 0 ? void 0 : _a.name,
			status: 'grpc',
			message: error.message
		};
		errorInfos.push(errorInfo);
	}
	for (const endorsement of proposalResponse.responses) {
		const errorInfo = {
			peer: (_b = endorsement === null || endorsement === void 0 ? void 0 : endorsement.connection) === null || _b === void 0 ? void 0 : _b.name,
			status: endorsement.response.status,
			message: endorsement.response.message
		};
		errorInfos.push(errorInfo);
	}
	const messages = ['No valid responses from any peers. Errors:'];
	for (const errorInfo of errorInfos) {
		messages.push(util.format('peer=%s, status=%s, message=%s', errorInfo.peer, errorInfo.status, errorInfo.message));
	}

	// return messages;
	let error = new Error();
	error.message = Util.prettyJSONString(errorInfos);
	return error;
}

function getResponsePayload(proposalResponse: any) {
	const validEndorsementResponse = getValidEndorsementResponse(proposalResponse.responses);
	if (!validEndorsementResponse) {
		const error = newEndorsementError(proposalResponse);
		throw error;
	}
	return validEndorsementResponse.response.payload;
}

// Construct an Identity context
export async function getIdentityContext(name: string, x509identity: EX509Identity) {
	const user = User.createUser(
		name,
		'',
		x509identity.mspId,
		x509identity.credentials.certificate,
		x509identity.credentials.privateKey);

	// Signer x509identityContext
	const client = new Client('IDX client');
	const userIdx = client.newIdentityContext(user);
	return userIdx;
}

/**
 * Sign a transaction manually
 *
 */
export function signTransaction(signerX509Identity: EX509Identity, proposalBytes: any) {
	const method = 'signTransaction';
	logger.start(method);

	const hashAlgo = 'sha256';
	try {
		const hash = crypto.createHash(hashAlgo);
		hash.update(proposalBytes);
		const digest = hash.digest('hex');
		const privateKeyPEM = signerX509Identity.credentials.privateKey;
		const { prvKeyHex } = KEYUTIL.getKey(privateKeyPEM); // convert the pem encoded key to hex encoded private key
		const EC = elliptic.ec;
		const ecdsaCurve = elliptic.curves.p256;
		const ecdsa = new EC(ecdsaCurve);
		const signKey = ecdsa.keyFromPrivate(prvKeyHex, 'hex');
		let sig = ecdsa.sign(Buffer.from(digest, 'hex'), signKey);
		sig = _preventMalleability(sig);
		const signature = Buffer.from(sig.toDER());

		logger.debug('%s - transaction signed', method);
		return signature;
	} catch (e: any) {
		logger.error('%s - %s', method, e.message);
		throw e;
	}
}

async function buildSignEndorsement(signer: Signer, transaction: Transaction, endorsement: Endorsement) {
	const method = 'buildSignEndorsement';
	logger.start(method);

	try {

		const signerCtx = signer.signerCtx;
		const signerX509Identity = signer.signerX509Identity;

		// Build proposal
		const proposalBytes = endorsement.build(signerCtx, transaction);

		// Sign proposal
		const signature = signTransaction(signerX509Identity, proposalBytes);

		// Sign endorsement
		endorsement.sign(signature);

		logger.debug('%s - proposal ready to send to peers', method);
		return endorsement;
	} catch (e: any) {
		logger.error('%s - %s', method, e.message);
		throw e;
	}
}

/* Send to endorsing peers */
async function sendEndorsement(endorsement: Endorsement, channel: Channel) {
	const method = 'sendEndorsement';
	logger.start(method);

	try {
		let proposalSendRequest = {} as ProposalSendRequest;
		proposalSendRequest.requestTimeout = 30000;

		// Set endorsers
		proposalSendRequest.targets = Array.from(channel.getEndorsers().values());

		// Send endorsement
		const proposalResponses = await endorsement.send(proposalSendRequest);

		logger.debug('%s - transaction endorsed with proposal response: %s', method, getResponsePayload(proposalResponses).toString());
		return { proposalResponses, endorsement };
	} catch (e: any) {
		logger.error('%s - %s', method, e.message[0].message);
		// logger.error(e);
		throw e;
	}
	// Construct request
}

async function buildSignCommit(signer: Signer, endorsement: Endorsement) {
	const method = 'buildSignCommit';
	logger.start(method);

	try {
		const signerCtx = signer.signerCtx;

		const commit = endorsement.newCommit();
		commit.build(signerCtx);
		commit.sign(signerCtx);

		logger.debug('%s - commit ready to send to orderers', method);
		return commit;
	} catch (e: any) {
		logger.error('%s - %s', method, e.message);
		throw e;
	}
}

async function sendCommit(commit: Commit, channel: Channel) {
	const method = 'sendCommit';
	logger.start(method);

	try {
		// Construct request
		const commitSendRequest = {} as ProposalSendRequest;
		commitSendRequest.requestTimeout = 30000;

		// Set committers (orderers)
		commitSendRequest.targets = Array.from(channel.getCommitters().values());
		const commitResponse = await commit.send(commitSendRequest);

		logger.debug('%s - commit sent, obtained response %j: ', method, commitResponse);
		return commitResponse;
	} catch (e: any) {
		logger.error('%s - %s', method, e.message);
		throw e;
	}

}
exports.sendCommit = sendCommit

/**
 * Get { Endorsement } instance
 *
 *
 *
 */
export async function getChannelCtx(clientID: string, channelID: string, chaincodeID: string) {
	const method = 'getChannelCtx';
	logger.start(method);
	const gateway = await Util.connectGateway(clientID);
	// @ts-ignore
	const channel = await gateway.client.channels.get(channelID);
	logger.debug('%s - : %s', method, channel);
	const endorsement = channel.newEndorsement(chaincodeID);

	return { channel, endorsement };
}


async function getEndorsementPayload(endorsement: Endorsement, channel: Channel) {
	const method = 'getEndorsementPayload';
	logger.start(method);

	const endorsementResponse = await sendEndorsement(endorsement, channel);
	const proposalResponses = endorsementResponse.proposalResponses;
	endorsement = endorsementResponse.endorsement;

	const transactionResult = getResponsePayload(proposalResponses).toString();

	return { endorsement, transactionResult };
}
exports.getEndorsementPayload = getEndorsementPayload

async function getSignerCtx(signerID: string, walletPath: string) {
	const method = 'getSignerCtx';
	logger.start(method);
	logger.debug('%s - signerID: %s', method, signerID);

	/* User Imports file ... */

	/* Handle to get credentials in an .id format */
	const wallet = await Wallets.newFileSystemWallet(walletPath);

	const signerX509Identity = await wallet.get(signerID) as EX509Identity;
	if (!signerX509Identity) {
		throw new Error('Identity not found in wallet');
	}
	const signerCtx = await getIdentityContext(signerID, signerX509Identity);

	return { signerCtx, signerX509Identity };
}

/**
 * Create, Sign and Commit transaction
 *
 *
 */
export async function sendTransaction(signerID: string, transaction: Transaction, channelID: string, chaincodeID: string) {
	const method = 'sendTransaction';
	logger.debug('%s - Creating transaction %s with SignerID: ', method, transaction.fcn, signerID);

	// let gateway = null;

	try {
		/* Backend
		*
		*/
		const channelCtx = await getChannelCtx(clientID, channelID, chaincodeID);
		const channel = channelCtx.channel;
		let endorsement = channelCtx.endorsement;

		/* Browser
		*
		*/
		// Get Signer CTX
		const signer = await getSignerCtx(signerID, walletPath);

		// Create Transaction (Build and sign endorsement)
		endorsement = await buildSignEndorsement(signer, transaction, endorsement);

		/* Backend
		*
		*/
		// Check for expired certificate 
		// const signatureHeader = decodeSignatureHeader(endorsement._action.header.signature_header)
		// const certificate = signatureHeader.creator.id_bytes.toString()
		// if (isRevoked(certificate)) {
		// 	throw new Error('Certificate is revoked.')
		// }

		// Gather endorsements
		const endorsementPayload = await getEndorsementPayload(endorsement, channel);
		const transactionResult = endorsementPayload.transactionResult;
		const signed_endorsement = endorsementPayload.endorsement;

		// console.log(endorsementPayload)
		/* Browser
		*
		*/
		// Build and sign commit
		const commit = await buildSignCommit(signer, signed_endorsement);

		/* Backend
		*
		*/
		// Send commit
		const commitResponse = await sendCommit(commit, channel);

		if (commitResponse.status === 'SUCCESS') {
			logger.debug('%s - Transaction committed successfully: result: ', method, transactionResult);
			return transactionResult;
		} else {
			logger.error('%s - failed to commit transaction', method);
			return commitResponse;
		}

	} catch (e: any) {
		// logger.error('%s - ', method, e.message);
		throw e;
	}
	// finally {
	// 	if (gateway) {gateway.disconnect();}
	// }

}

// /**
//  * Check if a certificate exists in local file as revoked
//  * 
//  * @param {String} certificate A PEM encoded certificate
//  * @returns {Bool} True if revoked, else false
//  * */
// function isRevoked(certificate: string) {
// 	const data = fs.readFileSync(revokedCertificates)
// 	let revokedCerts = (JSON.parse(data)).revokedCerts;
// 	return includes(revokedCerts, certificate)
// }

// function decodeSignatureHeader(signatureHeaderBuf: SignatureHeaderBuffer) {
// 	const signature_header = {};
// 	const signatureHeaderProto = fabproto6.common.SignatureHeader.decode(signatureHeaderBuf);
// 	signature_header.creator = decodeIdentity(signatureHeaderProto.creator);
// 	signature_header.nonce = signatureHeaderProto.nonce;

// 	return signature_header;
// }

// function decodeIdentity(identityBuf: any) {
// 	const identity = {};
// 	try {
// 		const identityProto = fabproto6.msp.SerializedIdentity.decode(identityBuf);
// 		identity.mspid = identityProto.mspid;
// 		identity.id_bytes = identityProto.id_bytes;
// 	} catch (err: any) {
// 		logger.error('Failed to decode the identity: %s', (err.stack ? err.stack : err));
// 	}

// 	return identity;
// }
