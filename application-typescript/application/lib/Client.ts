
import { Contract, Network, Gateway, GrpcClient, Signer } from '@hyperledger/fabric-gateway'
import UserContract from './UserContract';
import DataContract from './DataContract';
import SignOffline from './SignOffline';
import AgreementContract from './AgreementContract';
import Connection from './Connection'
import { IWalletCredentials, IClient } from './interfaces'

export class Client {

    channelID: string;
	chaincodeID: string;
	contract: Contract;
    network: Network;
    gateway: Gateway;
    dataContract: DataContract;
    userContract: UserContract;
    agreementContract: AgreementContract;
    mspPath: string | undefined;
    mspId: string;
    peerConnection: GrpcClient;
    x509Identity: IWalletCredentials | undefined;
    client: IClient;
    username: string | undefined;
    signOffline: SignOffline;
    signer: Signer | undefined;;

    constructor(peerConnection: GrpcClient, client: IClient) {
        if (!client.mspPath && !client.x509Identity) throw new Error('Missing mspPath or x509Identity')        
        // @ts-ignore
        this.mspId = client.mspId || client.x509Identity?.mspId
        this.username = client.username
        this.peerConnection = peerConnection
        this.mspPath = client.mspPath
        this.x509Identity = client.x509Identity
        this.client = client
    }

	/**
	 * Get All agreements
	 */    
    async init(channelID: string, chaincodeID: string) {
        this.gateway = await Connection.connectGateway(this.peerConnection, this.client)
        this.signer = await Connection.newSigner(this.client)
        this.channelID = channelID
        this.chaincodeID = chaincodeID
        this.network = this.gateway.getNetwork(this.channelID)
        this.contract = this.network.getContract(this.chaincodeID);
        // this.signOffline = new SignOffline(this.gateway, this.contract)
        this.dataContract = new DataContract(this.contract);
        this.userContract = new UserContract(this.contract);
        this.agreementContract = new AgreementContract(this.contract)
        this.signOffline = new SignOffline(this.gateway, this.contract)
    }

}

export default Client