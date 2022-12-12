// @ts-ignore

const mongoose = require('mongoose')

const Agreement = new mongoose.Schema({
		_id: { type: String },		
		type: { type: String },
		txID: { type: String },
		productID: { type: String },
		productType: { type: String },
		seller: { type: String },
		buyer: { type: String },
		price: { type: Number },
		status: { type: String },
		timestamp: { type: Number }
	}, 
	{ collection: 'agreements' }
)

Agreement.statics.deleteById = function(_id) {
	return this.deleteOne({ _id: _id })
};

const myDb = mongoose.connection.useDb(process.env.DB_LEDGER)
const model = mongoose.model('AgreementData', Agreement)

module.exports = model

