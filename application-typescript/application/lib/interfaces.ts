
'use strict'

import * as crypto from 'crypto';

import { X509Identity } from 'fabric-network';
import { IdentityContext } from 'fabric-common'
import { IEnrollResponse } from 'fabric-ca-client'
import { ProposalOptions } from '@hyperledger/fabric-gateway'

export { IdentityContext }
export { IEnrollResponse }

export interface ICA {
	orgName: string;
	caName: string;
	orgMSP: string;
	registrarID: string;
	type?: string;
}

export interface IClient {
	mspPath?: string;
	mspId?: string;
	x509Identity?: IWalletCredentials;
	username?: string;
}

export interface CryptoMaterial {
	enrollment: IEnrollResponse,
	privateKey: crypto.KeyObject,
	mspId: string,
	subjectDN: string,
	csr: string,
	publicKey: crypto.KeyObject
}

export interface IX509Identity {
	credentials: {
		certificate: string;
		privateKey?: string;
	};
	mspId: string;
	version?: number;
}

export interface IWalletCredentials {
	credentials: {
		certificate: string;
		privateKey: string;
	};
	mspId: string;
	version?: number;
}

export interface EX509Identity extends X509Identity {
	version?: number;
}

export interface IProposalProto { 
	bytes: Uint8Array;
	digest: Uint8Array; 
}

export interface IProposalOptions {
	name: string;
	options: ProposalOptions;
}

export interface Peer {
    endpoint: string,
    hostname: string,
    mspPath: string
}

export interface INetwork {
    channelID: string,
    chaincodeID: string
}

export interface IOrg {
	instType: string,
	orgName: string,
	active: boolean,
	members: Array<string>
}

export interface IUser {
	type: string,
	id: string,
	username: string,
	isOrg: boolean,
	org: IOrg,
	isBuyer: boolean,
	purposes: Array<string>,
	validTo: number,
	approvedOrgs?: Array<string>,
	[key: string]: any
}

export interface IInventory {
	owner: string,
	productID: string,
	[key: string]: any
}

// Agreement Declaration
export interface IAgreement {
	type: string,
	txID: string,
	productType: string,
	seller: string,
	buyer: string,
	price: number,
	status: string,
	timestamp: number,
	[key: string]: any
}

export interface IProduct {
	type: string,
	owner: string,
	id: string,
	name: string,
	price: number,
	desc: string,
	productType?: string,
	policy: Policy,
	timestamp: number,
	escrow?: string,
	curations?: Array<string>,
	productIDs?: Array<string>,
	[key: string]: any
}

// Status of an Agreement
export enum AgreementStatus {
	ELIGIBLE = "ELIGIBLE",
	PAID = "PAID",
	ACCESS = "ACCESS"
}

export interface Policy {
	inclPersonalInfo: boolean,
	hasConsent: boolean,
	purposes: Array<string>,
	protectionType: string,
	secondUseConsent: boolean,
	transferToCountry: boolean,
	storagePeriod: number
}

export interface BuyerParameters {
	purposes: Array<string>
}



export interface ReenrollResponse {
	certificate: string,
	rootCertificate: string
}

export interface Credentials {
	certificate: string,
	privateKey: crypto.KeyObject
}

export interface CertSerialAndAki {
	serial: string,
	aki: string
}


export interface Transaction {
	fcn: string,
	args: Array<string>
}

export interface Signer {
	signerCtx: IdentityContext,
	signerX509Identity: EX509Identity
}

export interface ProposalSendRequest {
	targets: any[],
	requestTimeout: number
}
