require('dotenv').config();
const appUserID = process.env.USERNAME;

exports.userIDs = ['user0', 'org0', 'org1', 'seller', 'buyer', 'institutional_buyer']

exports.org0 = {
	username: 'org0',
	isOrg: true,
	isMemberOf: "",
	org: {
		instType: 'privateHospitals',
		orgName: 'Lynkeus',
		// dpoFirstName: 'Bob',
		// dpoLastName: 'Bobinson',
		// dpoEmail: 'Bob@email.com',
		active: true,
		members: []
	},
	isBuyer: true,
	purposes: ['marketing'],
	active: true
};

exports.org1 = {
	username: 'org1',
	isOrg: true,
	isMemberOf: "",
	org: {
		instType: 'publicHospitals',
		orgName: 'Lynkeus',
		// dpoFirstName: 'Bob',
		// dpoLastName: 'Bobinson',
		// dpoEmail: 'Bob@email.com',
		active: true,
		members: []
	},
	isBuyer: true,
	purposes: ['private_research'],
	active: true
};

exports.user0 = {
	username: 'user0',
	isOrg: false,
	isMemberOf: "",
	org: {
		instType: 'privateHospitals',
		orgName: 'Lynkeus',
		// dpoFirstName: 'Bob',
		// dpoLastName: 'Bobinson',
		// dpoEmail: 'Bob@email.com',
		active: true,
		members: []
	},
	isBuyer: false,
	purposes: ['marketing'],
	active: true
};

exports.seller = {
	username: 'seller',
	isOrg: false,
	isMemberOf: "",
	isBuyer: false,
	purposes: ['marketing'],
	active: true
};

exports.buyer = {
	username: 'buyer',
	isOrg: false,
	isMemberOf: "",
	isBuyer: true,
	purposes: ['marketing'],
	active: true
};

exports.institutional_buyer = {
	username: 'institutional_buyer',
	isOrg: false,
	isMemberOf: "org0",
	isBuyer: true,
	purposes: ['marketing'],
	active: true
};

exports.product_preapproved_user = {
	name: 'PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: "Health",
	productType: "ANALYTICS",
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: ['marketing', 'publicly_funded_research'],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: ['publicHospitals', 'privateHospitals'],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedUsers: ["buyer"]
	},
};

exports.product_analytics = {
	name: 'PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: "Health",
	productType: "ANALYTICS",
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: ['marketing', 'publicly_funded_research'],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: ['publicHospitals', 'privateHospitals'],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: []
	},
};

exports.product_batch_automated = {
	name: 'PROD_BATCH_0',
	price: 10,
	desc: 'A simple blood test',
	sector: "Health",
	productType: "BATCH",
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: ['automated', 'publicly_funded_research'],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: ['publicHospitals', 'privateHospitals'],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: ['org0'],
		automated: ["automated_placing"]
	},
};


exports.product_batch = {
	name: 'PROD_BATCH_1',
	price: 10,
	desc: 'A simple blood test',
	sector: "Health",
	productType: "BATCH",
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: ['marketing'],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: ["privateResearch"],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: ['org0']
	},
};

exports.educational_product_batch = {
	name: 'EDU_PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: "Education",
	productType: "BATCH",
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: ['marketing'],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: ["hr_agencies"],
		transferToCountry: "eu",
		storagePeriod: 20,
		approvedOrgs: []
	},
};

exports.educational_product_analytics = {
	name: 'EDU_PROD_ANALYTICS',
	price: 10,
	desc: 'A simple blood test',
	sector: "Education",
	productType: "ANALYTICS",
	policy: {
		inclPersonalInfo: true,
		hasConsent: true,
		purposes: ['marketing'],
		protectionType: 'SMPC',
		secondUseConsent: true,
		recipientType: ["hr_agencies"],
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
