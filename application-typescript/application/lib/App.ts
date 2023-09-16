
import { prettyJSONString, prettyJSON, getLogger } from './libUtil'
import { Peer, INetwork, IClient } from './interfaces'
import SignOffline from './SignOffline'
import Transactions from './Transactions'
import Connection from './Connection'
import Client from './Client'
import BlockListener from './BlockListener'
import DBHandler from './Database'
import CAServices from './CAServices'
import { readdir, readFile } from 'fs/promises';
import { join } from 'path';

export class App {

    peerConnection: any
    channelID: string;
	chaincodeID: string;
    transactions: typeof Transactions;
    peer: Peer;
    clients: Map<any, any>;
    dbHandler: DBHandler;

    constructor(peer: Peer, network: INetwork) {
        this.peer = peer
        this.channelID = network.channelID
        this.chaincodeID = network.chaincodeID
        // this.connection = new Connection()
        // this.transactions = Transactions
        // this.signOffline = new SignOffline(NETWORK.channelID, NETWORK.chaincodeID)
        this.clients = new Map()
    }


    async importMSPs() {
        try {
            const directoryPath = './identities'
            // Read all filenames in the directory
            const filenames = await readdir(directoryPath);

            const ca = new CAServices(null)
            for (const filename of filenames) {
                try {
                    console.log(`Importing identity: ${filename}`)
                    await ca.importMSP(filename)
                } catch(e) {

                }
            }


    
        } catch (error) {
            console.error('An error occurred:', error);
        }
    }

    async init() {
        this.peerConnection = await Connection.newGrpcConnection(this.peer)
        await this.importMSPs()


    }

    async newClient(clientData: IClient) {
        const client = new Client(this.peerConnection, clientData)
        await client.init(this.channelID, this.chaincodeID)
        // TODO
        this.clients.set('mspPath', client)
        return client 
    }

    async newBlockListener(clientData: IClient) {
        const listener = new BlockListener(this.peerConnection, clientData)
        await listener.init(this.channelID, this.chaincodeID)
        return listener
    }

    async initDatabase(clientData: IClient) {
        const dbHandler = new DBHandler(this.peerConnection, clientData)
        await dbHandler.init(this.channelID, this.chaincodeID)
        return dbHandler
    }

    // async submitTx(signer, fcn) {
    //     return await this.signOffline.submitTx(signer, fcn)
    // }

};

export default App