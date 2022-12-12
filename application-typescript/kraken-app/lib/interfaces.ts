
'use strict'

import * as crypto from 'crypto';

import { X509Identity } from 'fabric-network';
import { IdentityContext } from 'fabric-common'
import { IEnrollResponse } from 'fabric-ca-client'

export { IdentityContext }
export { IEnrollResponse }

export interface EX509Identity extends X509Identity {
	version?: number;
}

export interface IUser {
	type: string,
	id: string,
	username: string,
	isOrg: boolean,
	org: Org,
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

export interface Org {
	instType: string,
	orgName: string,
	dpoFirstName: string,
	dpoLastName: string,
	dpoEmail: string,
	active: boolean
}



export interface ReenrollResponse {
	certificate: string,
	rootCertificate: string
}

export interface Credentials {
	certificate: string,
	privateKey: crypto.KeyObject
}

export interface CryptoMaterial {
	enrollment: IEnrollResponse,
	privateKey: crypto.KeyObject,
	mspId: string,
	subjectDN: string,
	csr: string,
	publicKey: crypto.KeyObject
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
