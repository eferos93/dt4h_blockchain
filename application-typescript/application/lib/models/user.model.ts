import mongoose, { Schema, Document, Model } from 'mongoose';
import { DATABASE } from '../Config';

interface IOrg {
    instType: string;
    orgName: string;
    active: boolean;
    members: string[];
}

const OrgSchema: mongoose.Schema = new Schema({
    instType: { type: String },
    orgName: { type: String },
    active: { type: Boolean },
    members: { type: [String] },
});

interface IUser extends Document {
    type: string;
    id: string;
    username: string;
    mspid: string;
    isOrg: boolean;
    isMemberOf: string;
    org: IOrg;
    isBuyer: boolean;
    purposes: string[];
    validTo: string;
    certKey: string;
    active: boolean;
    vers: number;
}

interface IUserModel extends mongoose.Model<IUser> {
    deleteById(_id: string): Promise<void>;
}

const UserSchema: mongoose.Schema = new Schema({
    _id: { type: String },
    type: { type: String },
    id: { type: String },
    username: { type: String },
    mspid: { type: String },
    isOrg: { type: Boolean },
    isMemberOf: { type: String },
    org: { type: OrgSchema },
    isBuyer: { type: Boolean },
    purposes: { type: [String] },
    validTo: { type: String },
    certKey: { type: String },
    active: { type: Boolean },
    vers: { type: Number },
}, { collection: 'users' });

UserSchema.statics.deleteById = function(_id: string): Promise<void> {
    return this.deleteOne({ _id: _id });
};

const myDb = mongoose.connection.useDb(DATABASE.name as string);
//@ts-ignore
export const model: IUserModel = myDb.model<IUser, IUserModel>('UserData', UserSchema);

export default model;
