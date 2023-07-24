
const test_data = require('./application/tests/test_data')
const { App } = require('./application/dist/App')
const { GATEWAY_PEER, NETWORK } = require('./application/dist/Config')
const fs = require('fs').promises;
const Transaction = require('./application/dist/Transactions').default

// Require relevant libs
const {
	UserContract,
	DataContract,
	// AgreementContract,
	Query,
	OffchainDB,
	CAServices,
	Crypto,
	Util
} = require('./application');

(async () => {
    let res;

    // Init modules and connect to peer gateway
    const app = new App(GATEWAY_PEER, NETWORK)
    await app.init()

    // Create a gateway based on the client's identity
    const clientData = {
    //   mspPath: "./identities/blockClient",
    //   mspId: "AgoraUsersMSP",
        x509Identity: JSON.parse(await fs.readFile('./wallet/user0.id')),
        type: "X.509",
        version: 1,
    };

    const listenerClient = {
        mspPath: './identities/blockClient',
        mspId: 'AgoraMSP',
        type: "X.509",
        version: 1,        
    }

    const client = await app.newClient(clientData)
    const blockClient = await app.newClient(listenerClient)
    
    // ------------- CONTRACTS TEST ------------

    // res = await client.userContract.createUser(test_data.user0)
    // console.log(res)
    // await Util.sleep(3000)

    res = await client.signOffline.submitTx(client.signer, Transaction.user.create(test_data.user0))
    console.log(res)
    await Util.sleep(3000)

    // res = await client.userContract.updateUser(test_data.user0)
    // // console.log(res)
    // res = await client.userContract.readUser(test_data.user0.username)
    // console.log(res)
    // res = await client.userContract.deleteUser(test_data.user0.username)
    // await sleep(3000)
    // res = await client.userContract.getUsers()
    // console.log(res)
    // let res = await client.dataContract.createProduct(test_data.product_analytics)
    // const signer = await app.connection.newSigner('./identities/blockClient');


    // ------------- BLOCK LISTENER TEST ------------
    // const listener = await app.newBlockListener(listenerClient)
    // await listener.run()
    
    // ------------- DB HANDLER TEST ------------
    // const dbHandler = await app.initDatabase(blockClient)
    // console.log(await dbHandler.runValidate())


    // // app.connection.disconnectClient(this.client)
})()




