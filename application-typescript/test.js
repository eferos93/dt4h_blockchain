
const fs = require('fs').promises;

const test_data = require('./application/tests/test_data')
const { 
    App, 
    Config,
    Transaction,
    Util
} = require('./application/dist');


(async () => {
    let args = process.argv.slice(2);
    
    // if(args.length === 0) {
        //     console.log('Please provide command line arguments.');
        //     process.exit(1);
    // }
        
    let mode = args[0];
    let dbHandler;
    let blockClient;
    
    // Init modules and connect to peer gateway
    const app = new App(Config.GATEWAY_PEER, Config.NETWORK)
    await app.init()
    
    switch(mode) {
        case 'db':
            if (!args.length > 2) {
                console.log('Please provide command line arguments.');
                process.exit(1);                
            }
            let action = args[1]
            switch(action) {
                case 'listen':
                    //  ------------- BLOCK LISTENER ------------
                    console.log('Initiating blockchain event DB listener.')
                    const listener = await app.newBlockListener(Config.BLOCK_LISTENER_CLIENT)
                    await listener.run()
                    break;
                case 'validate':
                    blockClient = await app.newClient(Config.BLOCK_LISTENER_CLIENT)
                    dbHandler = await app.initDatabase(blockClient)
                    await dbHandler.runValidate()                    
                    break;
                case 'drop':
                    blockClient = await app.newClient(Config.BLOCK_LISTENER_CLIENT)
                    dbHandler = await app.initDatabase(blockClient)
                    await dbHandler.drop()                    
                    break;
                default:
                    console.log('Unknown command.')
                    break
            }
            break;
    }


    // Create a gateway based on the client's identity
    const clientData = {
        //   mspPath: "./identities/blockClient",
        //   mspId: "AgoraUsersMSP",
            x509Identity: JSON.parse(await fs.readFile('./wallet/test.id')),
            type: "X.509",
            version: 1,
        };
    


    let res;
    console.log(clientData)

    const client = await app.newClient(clientData)
    
    
    // ------------- CONTRACTS TEST ------------

    const tt = {
        username: 'test12314',
        isOrg: false,
        isMemberOf: "",
        org: {
            instType: 'PrivateResearch',
            orgName: 'Lynkeus',
            // dpoFirstName: 'Bob',
            // dpoLastName: 'Bobinson',
            // dpoEmail: 'Bob@email.com',
            active: true,
            members: []
        },
        isBuyer: false,
        purposes: ['Marketing'],
        active: true
    };

    res = await client.userContract.createUser(tt)
    console.log(res)
    // await Util.sleep(3000)
    // console.log(Transaction.product.create(test_data.product_analytics))
    // res = await client.signOffline.submitTx(client.signer, Transaction.product.create(test_data.product_analytics))
    // console.log(res)
    // await Util.sleep(3000)

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



    // // app.connection.disconnectClient(this.client)
})()




