const mongoose = require('mongoose');

const Org = new mongoose.Schema({
    instType: { type: String },
    orgName: { type: String },
    active: { type: Boolean },
    members: { type: [String] },
});

const modelOrg = mongoose.model('OrgData', Org);

const User = new mongoose.Schema({
    _id: { type: String },
    type: { type: String },
    id: { type: String },
    username: { type: String },
    mspid: { type: String },
    isOrg: { type: Boolean },
    isMemberOf: { type: String },
    org: { type: Org },
    isBuyer: { type: Boolean },
    purposes: { type: [String] },
    validTo: { type: String },
    certKey: { type: String },
    active: { type: Boolean },
    vers: { type: Number }
}, { collection: 'users' });

User.statics.deleteById = function (_id: any) {
    return this.deleteOne({ _id: _id });
};

const myDb = mongoose.connection.useDb(process.env.DB_LEDGER)
const model = mongoose.model('UserData', User);

module.exports = model;
