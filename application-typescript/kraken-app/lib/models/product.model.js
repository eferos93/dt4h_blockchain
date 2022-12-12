// @ts-ignore
const mongoose = require('mongoose')

const Policy = new mongoose.Schema({
		inclPersonalInfo: { type: Boolean },
		hasConsent: { type: Boolean },
		purposes: { type: [String] },
		protectionType: { type: String },
		secondUseConsent: { type: Boolean },
		recipientType: { type: [String] },
		transferToCountry: { type: String },
		storagePeriod: { type: Number },
		approvedOrgs: { type: [String] },
		approvedUsers: { type: [String] },
		automated: { type: [String] },
	}
)

const modelPolicy = mongoose.model('PolicyData', Policy)

const Product = new mongoose.Schema({
	  	_id: { type: String },
		type: { type: String },
		owner: { type: String },
		id: { type: String },
		name: { type: String },
		price: { type: Number },
		desc: { type: String },
		sector: { type: String },
		productType: { type: String },
		policy: { type: Policy },
		timestamp: { type: Number },
		curations: { type: [String] },
	},
	{ collection: 'products' }
)

Product.statics.deleteById = function(_id) {
  return this.deleteOne({ _id: _id })
};

Product.index({ owner: 1})

const myDb = mongoose.connection.useDb(process.env.DB_LEDGER)
const model = mongoose.model('ProductData', Product)

module.exports = model
