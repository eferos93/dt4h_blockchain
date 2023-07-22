import mongoose, { Schema } from 'mongoose';
import { DATABASE } from '../Config';

interface IPolicy extends mongoose.Document {
	inclPersonalInfo: boolean;
	hasConsent: boolean;
	purposes: string[];
	protectionType: string;
	secondUseConsent: boolean;
	recipientType: string[];
	transferToCountry: string;
	storagePeriod: number;
	approvedOrgs: string[];
	approvedUsers: string[];
	automated: string[];
	vers: number;
}

const PolicySchema: mongoose.Schema = new Schema({
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
	vers: { type: Number }
});

interface IProduct extends Document {
	_id: string;
	type: string;
	owner: string;
	id: string;
	name: string;
	price: number;
	desc: string;
	sector: string;
	productType: string;
	policy: IPolicy;
	timestamp: number;
	curations: string[];
	vers: number;
}

interface IProductModel extends mongoose.Model<IProduct> {
	deleteById(_id: string): Promise<void>;
}

const ProductSchema: mongoose.Schema = new Schema({
	_id: { type: String },
	type: { type: String },
	owner: { type: String },
	id: { type: String },
	name: { type: String },
	price: { type: Number },
	desc: { type: String },
	sector: { type: String },
	productType: { type: String },
	policy: { type: PolicySchema },
	timestamp: { type: Number },
	curations: { type: [String] },
	vers: { type: Number }
},
	{ collection: 'products' }
);

ProductSchema.statics.deleteById = function (_id: string): Promise<void> {
	return this.deleteOne({ _id: _id });
};

ProductSchema.index({ owner: 1 });

const myDb = mongoose.connection.useDb(DATABASE.name as string);
// @ts-ignore
export const model: IProductModel = myDb.model<IProduct, IProductModel>('ProductData', ProductSchema);

export default model;
