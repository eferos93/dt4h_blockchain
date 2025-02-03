
const fs = require('fs').promises;

const { 
    App, 
    Config,
    Transaction,
    Util
} = require('./application');


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
                    console.log('Listener initialized.')
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
    


})()




