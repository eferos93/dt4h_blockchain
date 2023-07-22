import mongoose from 'mongoose';
import { DATABASE } from "../Config";

// Define an interface for the schema
interface IAgreementSchema extends Document {
    _id: string;
    type: string;
    txID: string;
    productID: string;
    productType: string;
    seller: string;
    buyer: string;
    price: number;
    status: string;
    timestamp: number;
}

// Define an interface for the model and statics
interface IAgreementModel extends mongoose.Model<IAgreementSchema> {
    deleteById(_id: string): Promise<void>;
}

const AgreementSchema: mongoose.Schema<IAgreementSchema> = new mongoose.Schema({
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
);

AgreementSchema.statics.deleteById = function(_id: string): Promise<void> {
    return this.deleteOne({ _id: _id });
};

const myDb = mongoose.connection.useDb(DATABASE.name);
// @ts-ignore
export const model: IAgreementModel = myDb.model<IAgreementSchema, IAgreementModel>('AgreementData', AgreementSchema);

export default model;
