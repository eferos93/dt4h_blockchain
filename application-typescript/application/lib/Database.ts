/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */


import { OffchainDB } from "./ReplicateDB";
import { getLogger } from "./libUtil";
import { Gateway, Network, GrpcClient } from '@hyperledger/fabric-gateway';
import Connection from './Connection'
import { IClient, IUser, IProduct, IAgreement } from './interfaces'
import Client from './Client'
import * as util from './libUtil'

const logger = getLogger('Database')

export class DBHandler extends OffchainDB {

    private client: Client;
    private channelID: string;
    private chaincodeID: string;
    private peerConnection: GrpcClient;
    private data_users_bc: Array<any>;
    private data_users_db: Array<any>;
    private data_products_bc: Array<any>;
    private data_products_db: Array<any>;
    private data_agreements_bc: Array<any>;
    private data_agreements_db: Array<any>;

    /**
     * Create a new DB Handler.
     * @param {GrpcClient} peerConnection - The peer connection.
     * @param {IClient} clientData - The client instance.
     */
    constructor(peerConnection: GrpcClient, clientData: IClient) {
        super()
        this.peerConnection = peerConnection
        this.client = new Client(this.peerConnection, clientData)
    }

    /**
     * Initialize the BlockListener.
     * @param {string} channelID - The channel ID.
     * @param {string} chaincodeID - The chaincode ID.
     */
    async init(channelID: string, chaincodeID: string): Promise<void> {
        this.channelID = channelID
        this.chaincodeID = chaincodeID
        await this.client.init(this.channelID, this.chaincodeID)
        await this.connect()
    }

    setClient(client: Client) {
        this.client = client
    }


    validateUser = (user_bc: IUser) => {
        const user_db = (this.data_users_db as any).find(item => item.username == user_bc.username)
        if (!user_db) throw new Error(`Missing from db: ${user_bc.id}`)
        if (!util.isEqualCommonProperties(user_db, user_bc)) throw new Error(`Not equal user ${user_bc.username}`)
    }

    validateById = (item_bc: IProduct | IAgreement | IUser) => {
        const item_db = (this.data_users_db as any).find(item => item.id == item_bc.id)
        if (!item_db) throw new Error(`Missing from db: ${item_bc.id}`)
        if (!util.isEqualCommonProperties(item_db, item_bc)) throw new Error(`Not equal product ${item_bc.id}`)
    }

    async validate() {
        const method = 'validate'

        try {
            if (!this.client) throw new Error(`Missing client`)

            let data_bc: any;
            let data_db: any;
            
            // Verify users
            data_bc = await this.client.userContract.getAll()
            data_db = await this.users.getAll()
            this.data_users_bc = data_bc
            this.data_users_db = data_db

            if (!data_bc?.length) return
            if (data_bc.length !== data_db.length) throw new Error('Not equal total number of users')
            data_bc.forEach(item_bc => this.validateUser(item_bc))

            // Verify products
            data_bc = await this.client.dataContract.getAll()
            data_db = await this.products.getAll()
            this.data_products_bc = data_bc
            this.data_products_db = data_db

            if (!data_bc?.length) return
            if (data_bc.length !== data_db.length) throw new Error('Not equal total number of products')
            data_bc.forEach(item_bc => this.validateById(item_bc))


        } catch(e: any) {
            logger.error(`${method} - ${e}`)
        }
    }

    /**
     * Run validator continuously
     */
    async runValidate() {
        const method = 'runValidate';

        setInterval(async () => {
            try {
                await this.validate()
                logger.info(`${method} - Valid`);
            } catch(e: any) {
                logger.error(`${method} - ${e}`);
            }
        }, 5*1000);
    }


}

export default DBHandler