/**
 * Copyright Lynkeus 2022. All Rights Reserved.
 *
 * @file Various Smart Contract function calls
 * @author: Alexandros Tragkas
 */

import { prettyJSONString } from './libUtil';
import { IUser, IProduct } from './interfaces'

interface ITransactionData {
    name: string;
    options?: {
        arguments: string[] | string;
    }
}

export class Transactions {
    user: User;
    product: Product;
    agreement: Agreement;

    constructor() {
        this.user = new User();
        this.product = new Product();
        this.agreement = new Agreement();
    }
}

class Agreement {
    private contract: string;
    private getAgreementTx: string;
    private getAllTx: string;
    private updateAgreementTx: string;

    constructor() {
        this.contract = 'AgreementContract';
        this.getAgreementTx = 'GetAgreement';
        this.getAllTx = 'GetAgreements';
        this.updateAgreementTx = 'UpdateAgreement';
    }

    update(id: string, status: string) {
        return { name: `${this.contract}:${this.updateAgreementTx}`, 
        options: { 
            arguments: [id, status]
        } };
    }

    /**
     * Read a specific Agreement by its id.
     * @param {string} id - The id of the Agreement.
     * @return {ITransactionData} The transaction data.
     */
    read(id: string): ITransactionData {
        return { name: `${this.contract}:${this.getAgreementTx}`, options: { arguments: id } };
    }

    getAll(): ITransactionData {
        return { name: `${this.contract}:${this.getAllTx}` };
    }
}


class Product {

    private contract: string;
    private createProductTx: string;
    private readProductTx: string;
    private updateProductTx: string;
    private deleteProductTx: string;
    private buyProductTx: string;
    private getAllTx: string;
    private getHistoryTx: string;

    constructor() {
        this.contract = 'DataContract';
        this.createProductTx = 'CreateProduct';
        this.readProductTx = 'ReadProduct';
        this.updateProductTx = 'UpdateProduct';
        this.deleteProductTx = 'DeleteProduct';
        this.buyProductTx = 'BuyProduct';
        this.getAllTx = 'GetAllProducts';
        this.getHistoryTx = 'GetHistoryOfProduct';
    }

    /**
     * Create a Product.
     * @param {object} obj - The Product object.
     * @return {ITransactionData} The transaction data.
     */
    create(obj: IProduct): ITransactionData {
        return { name: `${this.contract}:${this.createProductTx}`, options: { arguments: [prettyJSONString(obj)] } };
    }

    /**
     * Updates a product.
     * @param {object} obj - The product object to update.
     * @return {ITransactionData} The transaction data.
     */
    update(obj: object): ITransactionData {
        return { name: `${this.contract}:${this.updateProductTx}`, options: { arguments: [prettyJSONString(obj)] } };
    }

    /**
     * Reads a product by its id.
     * @param {string} id - The id of the product to read.
     * @return {ITransactionData} The transaction data.
     */
    read(id: string): ITransactionData {
        return { name: `${this.contract}:${this.readProductTx}`, options: { arguments: id } };
    }

    /**
     * Deletes a product by its id.
     * @param {string} id - The id of the product to delete.
     * @return {ITransactionData} The transaction data.
     */
    delete(id: string): ITransactionData {
        return { name: `${this.contract}:${this.deleteProductTx}`, options: { arguments: id } };
    }

    /**
     * Buys a product.
     * @param {string} id - The id of the product to buy.
     * @param {object} buyerParams - The parameters of the buyer.
     * @return {ITransactionData} The transaction data.
     */
    buy(id: string, buyerParams: object): ITransactionData {
        return {
            name: `${this.contract}:${this.buyProductTx}`,
            options: { arguments: [id, prettyJSONString(buyerParams)] },
        };
    }

    /**
     * Get all products
     *
     * @returns {ITransactionData} The function call name and arguments
     */
    getAll(): ITransactionData {
        return { name: `${this.contract}:${this.getAllTx}` };
    }
    
    /**
     * Get history of product
     * @param {string} id - The id of the product to buy.
     * @returns {ITransactionData} The function call name and arguments
     */
    getHistory(id: string): ITransactionData {
        return {
            name: `${this.contract}:${this.getHistoryTx}`,
            options: { arguments: id }         
        };    
    }
    
}

class User {

    private contract: string;
    private createUserTx: string;
    private updateUserTx: string;
    private readUserTx: string;
    private deleteUserTx: string;
    private getAllTx: string;

    constructor() {
        this.contract = 'UserContract';
        this.createUserTx = 'CreateUser';
        this.updateUserTx = 'UpdateUser';
        this.readUserTx = 'ReadUser';
        this.deleteUserTx = 'DeleteUser';
        this.getAllTx = 'GetAllUsers'
    }

    /**
     * Create a User.
     * @param {object} obj - The User object.
     * @return {ITransactionData} The transaction data.
     */
    create(obj: object): ITransactionData {
        return { name: `${this.contract}:${this.createUserTx}`, options: { arguments: [prettyJSONString(obj)] } };
    }

    /**
     * Update a user
     *
     * @param {IUser} obj - The user object that is to be updated
     * @returns {Object} The function call name and arguments
     */
    update(obj: IUser): ITransactionData {
        return { name: `${this.contract}:${this.updateUserTx}`, options: { arguments: [prettyJSONString(obj)] } };
    }

    /**
     * Read a user
     *
     * @param {string} username - The username of the user to be read
     * @returns {Object} The function call name and arguments
     */
    read(username: string): ITransactionData {
        return { name: `${this.contract}:${this.readUserTx}`, options: { arguments: [username] } };
    }

    /**
     * Delete a user
     *
     * @param {string} username - The username of the user to be deleted
     * @returns {Object} The function call name and arguments
     */
    delete(username: string): ITransactionData {
        return { name: `${this.contract}:${this.deleteUserTx}`, options: { arguments: [username] } };
    }

    /**
     * Get all users
     *
     * @returns {ITransactionData} The function call name and arguments
     */
    getAll(): ITransactionData {
        return { name: `${this.contract}:${this.getAllTx}` };
    }
    
    test() {
        return { name: this.contract + ':Test' };
    }
}

export default new Transactions()
