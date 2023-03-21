require('dotenv').config();
const appUserID = process.env.USERNAME;
const t = require('./consts')
exports.userIDs = ['user0', 'org0', 'org1', 'seller', 'buyer', 'institutional_buyer']

exports.org0 = {
	username: 'org0',
	isOrg: true,
	isMemberOf: "",
	org: {
		instType: t.T_PRIVATEHOSPITALS,
		orgName: 'Lynkeus',
		// dpoFirstName: 'Bob',
		// dpoLastName: 'Bobinson',
		// dpoEmail: 'Bob@email.com',
		active: true,
		members: []
	},
	isBuyer: true,
	purposes: [t.P_MARKETING],
	active: true
};

exports.org1 = {
	username: 'org1',
	isOrg: true,
	isMemberOf: "",
	org: {
		instType: t.T_PUBLICHOSPITALS,
		orgName: 'Lynkeus',
		// dpoFirstName: 'Bob',
		// dpoLastName: 'Bobinson',
		// dpoEmail: 'Bob@email.com',
		active: true,
		members: []
	},
	isBuyer: true,
	purposes: [t.P_PRIVATERESEARCH],
	active: true
};

exports.user0 = {
	username: 'user0',
	isOrg: false,
	isMemberOf: "",
	org: {
		instType: t.T_PRIVATEHOSPITALS,
		orgName: 'Lynkeus',
		// dpoFirstName: 'Bob',
		// dpoLastName: 'Bobinson',
		// dpoEmail: 'Bob@email.com',
		active: true,
		members: []
	},
	isBuyer: false,
	purposes: [t.P_MARKETING],
	active: true
};

exports.seller = {
	username: 'seller',
	isOrg: false,
	isMemberOf: "",
	isBuyer: false,
	purposes: [t.P_MARKETING],
	active: true
};

exports.buyer = {
	username: 'buyer',
	isOrg: false,
	isMemberOf: "",
	isBuyer: true,
	purposes: [t.P_MARKETING],
	active: true
};

exports.institutional_buyer = {
	username: 'institutional_buyer',
	isOrg: false,
	isMemberOf: "org0",
	isBuyer: true,
	purposes: [t.P_MARKETING],
	active: true
};

exports.product_preapproved_user = {
	name: 'PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: t.S_HEALTH,
	productType: t.T_ANALYTICS,
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: [t.P_MARKETING, t.P_PUBLICLY_FUNDED_RESEARCH],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: [t.T_PUBLICHOSPITALS, t.T_PRIVATEHOSPITALS],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedUsers: ["buyer"]
	},
};

exports.product_analytics = {
	name: 'PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: t.S_HEALTH,
	productType: t.T_ANALYTICS,
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: [t.P_MARKETING, t.P_PUBLICLY_FUNDED_RESEARCH],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: [t.T_PUBLICHOSPITALS, t.T_PRIVATEHOSPITALS],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: []
	},
};

exports.product_batch_automated = {
	name: 'PROD_BATCH_0',
	price: 10,
	desc: 'A simple blood test',
	sector: t.S_HEALTH,
	productType: t.T_BATCH,
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: [t.P_AUTOMATED, t.P_PUBLICLY_FUNDED_RESEARCH],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: [t.T_PUBLICHOSPITALS, t.T_PRIVATEHOSPITALS],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: ['org0'],
		automated: [t.P_AUTOMATED_PLACING]
	},
};


exports.product_batch = {
	name: 'PROD_BATCH_1',
	price: 10,
	desc: 'A simple blood test',
	sector: t.S_HEALTH,
	productType: t.T_BATCH,
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: [t.P_MARKETING],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: [t.P_PRIVATERESEARCH],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: ['org0']
	},
};

exports.educational_product_batch = {
	name: 'EDU_PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: t.S_EDU,
	productType: t.T_BATCH,
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: [t.P_MARKETING],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: [t.T_HRAGENCIES],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: []
	},
};

exports.educational_product_analytics = {
	name: 'EDU_PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: t.S_EDU,
	productType: t.T_ANALYTICS,
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: [t.P_MARKETING],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: [t.T_HRAGENCIES],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: []
	},
};

exports.getUser = (input) => { 
	for (let obj of Object.values(module.exports)) {

		if (obj.username && obj.username === input) {
			return obj
		}
	}
	return null
}
