import { Gateway, Contract, Network, Signer, Proposal, Transaction, Commit, Status, GrpcClient } from '@hyperledger/fabric-gateway';
import { IProposalOptions, IProposalProto  } from './interfaces'
import { getLogger } from './libUtil'

const logger = getLogger('SignOffline')

/**
 * Class to handle the offline signing of Hyperledger Fabric transactions
 * @class
 */
export class SignOffline {

    private contract: Contract;
    private gateway: Gateway | undefined;
	private channelID: string;
	private chaincodeID: string;

    constructor(gateway, contract) {
        this.gateway = gateway
        this.contract = contract
        // this.channelID = channelID,
        // this.chaincodeID = chaincodeID
    }

    async setGateway(gateway: Gateway) {
        this.gateway = gateway
        this.contract = gateway.getNetwork(this.channelID).getContract(this.chaincodeID);

        console.log(this.contract)
    }

    /**
     * Signs the digest using the provided signer
     * @param {Signer} signer - The signer
     * @param {Uint8Array} digest - The digest to be signed
     * @returns {Promise<Uint8Array>} - The signature
     */
    async signDigest(signer: Signer, digest: Uint8Array): Promise<Uint8Array> {
        return signer(digest);
    }

    /**
     * Gets the bytes and digest from the proposal
     * @param {Proposal | Transaction | Commit} proposal - The proposal
     * @returns {IProposalProto} - The bytes and digest of the proposal
     */
    private getBytesAndDigest(proposal: Proposal | Transaction | Commit): IProposalProto {
        const bytes = proposal.getBytes();
        const digest = proposal.getDigest();
        return { bytes, digest };
    }

    /**
     * Builds a proposal
     * @param {IProposalOptions} fcn - The function to call and its options
     * @returns {IProposalProto} - The bytes and digest of the proposal
     */
    private buildProposal(fcn: IProposalOptions): IProposalProto {
        const unsignedProposal = this.contract.newProposal(fcn.name, fcn.options);
        return this.getBytesAndDigest(unsignedProposal);
    }

    /**
     * Endorses the proposal
     * @param {IProposalProto} proposal - The proposal
     * @param {Uint8Array} proposalSignature - The proposal's signature
     * @returns {Promise<UnsignedTransaction>} - The endorsed proposal
     */
    private async endorseProposal(proposal: IProposalProto, proposalSignature: Uint8Array): Promise<Transaction> {
        const signedProposal: Proposal = this.gateway!.newSignedProposal(proposal.bytes, proposalSignature);
        return signedProposal.endorse();
    }

    /**
     * Submits the transaction
     * @param {IProposalProto} transaction - The transaction
     * @param {Uint8Array} transactionSignature - The transaction's signature
     * @returns {Promise<{ signedTransaction: Transaction, unsignedCommit: Commit }>} - The signed transaction and the unsigned commit
     */
    private async submitTransaction(transaction: IProposalProto, transactionSignature: Uint8Array): Promise<{ signedTransaction: Transaction, unsignedCommit: Commit }> {
        const signedTransaction: Transaction = this.gateway!.newSignedTransaction(transaction.bytes, transactionSignature);
        return { signedTransaction, unsignedCommit: await signedTransaction.submit() };
    }

    /**
     * Submits the commit
     * @param {IProposalProto} commit - The commit
     * @param {Uint8Array} commitSignature - The commit's signature
     * @returns {Promise<string>} - The status of the submitted commit
     */
    private async submitCommit(commit: IProposalProto, commitSignature: Uint8Array): Promise<Status> {
        const signedCommit: Commit = this.gateway!.newSignedCommit(commit.bytes, commitSignature);
        return signedCommit.getStatus();
    }

    /**
     * Signs a transaction offline
     * @param {Signer} signer - The signer
     * @param {IProposalOptions} fcn - The function to call and its options
     * @returns {Promise<{ status: string, result: Buffer }>} - The status and result of the transaction
     */
    async submitTx(signer: Signer, fcn: IProposalOptions): Promise<{ status: number, result: any }> {

        // Create proposal digest
        const proposal = this.buildProposal(fcn);

        // Offline sign proposal
        const proposalSignature = await this.signDigest(signer, proposal.digest);

        // Gather endorsements
        const unsignedTransaction = await this.endorseProposal(proposal, proposalSignature);

        // Create transaction digest
        const transaction = this.getBytesAndDigest(unsignedTransaction);

        // Offline sign transaction
        const transactionSignature = await this.signDigest(signer, transaction.digest);

        // Submit transaction
        const { signedTransaction, unsignedCommit } = await this.submitTransaction(transaction, transactionSignature);

        // // Create commit digest
        // const commit = this.getBytesAndDigest(unsignedCommit);

        // // Offline sign commit
        // const commitSignature = await this.signDigest(signer, commit.digest);

        // Get transaction result and status
        // const result = signedTransaction.getResult();
        // const status = await this.submitCommit(commit, commitSignature);

        return { status: 0, result: '' };
        // return { status, result };
    }


    /**
     * Sign a transaction manually
     *
     */
    // signTransaction(privateKeyPEM: string, proposalBytes: any) {
    //     const method = 'signTransaction';

    //     const hashAlgo = 'sha256';
    //     try {
    //         const hash = crypto.createHash(hashAlgo);
    //         hash.update(proposalBytes);
    //         const digest = hash.digest('hex');
    //         const { prvKeyHex } = KEYUTIL.getKey(privateKeyPEM); // convert the pem encoded key to hex encoded private key
    //         const EC = elliptic.ec;
    //         const ecdsaCurve = elliptic.curves.p256;
    //         const ecdsa = new EC(ecdsaCurve);
    //         const signKey = ecdsa.keyFromPrivate(prvKeyHex, 'hex');
    //         let sig = ecdsa.sign(Buffer.from(digest, 'hex'), signKey);
    //         sig = _preventMalleability(sig);
    //         const signature = Buffer.from(sig.toDER());

    //         logger.debug('%s - transaction signed', method);
    //         return signature;
    //     } catch (e: any) {
    //         logger.error('%s - %s', method, e.message);
    //         throw e;
    //     }
    // }
}


export default SignOffline