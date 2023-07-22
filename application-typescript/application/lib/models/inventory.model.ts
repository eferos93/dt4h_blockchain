import mongoose from 'mongoose'
import { DATABASE } from '../Config'

const Inventory = new mongoose.Schema({

        _id: { type: String },
        productID: { type: String },
        owner: { type: String }
},
        { collection: 'inventory' }
)

const myDb = mongoose.connection.useDb(DATABASE.name)
export const model = myDb.model('InventoryData', Inventory)

export default model

