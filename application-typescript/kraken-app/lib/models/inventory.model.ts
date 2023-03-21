// @ts-ignore
const mongoose = require('mongoose')

const Inventory = new mongoose.Schema({

        _id: { type: String },
        productID: { type: String },
        owner: { type: String }
	}, 
	{ collection: 'inventory' }
)

const myDb = mongoose.connection.useDb(process.env.DB_LEDGER)
const model = mongoose.model('InventoryData', Inventory)

module.exports = model

