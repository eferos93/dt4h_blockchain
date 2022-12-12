/**
 * Copyright Lynkeus 2020. All Rights Reserved.
 *
 * @file Helper functions
 * @module libUtil
 * @author Alexandros Tragkas
 */

'use strict';

const TYPE = 'Util';

/* Dependencies */
// const winston = require('winston')
import * as winston from 'winston';
import * as process from 'process';
import * as path from 'path';
import * as yaml from 'js-yaml';
import * as fs from 'fs';

import { Gateway, Wallets, DefaultEventHandlerStrategies } from 'fabric-network';
const config = winston.config;
require('dotenv').config();

/* Env */
const walletPath: string = path.join(process.env.WALLET_PATH!);
const ccpPath: string = path.resolve(process.env.CCP_PATH!);
const AS_LOCALHOST: string = process.env.AS_LOCALHOST!.toLowerCase()

export function toBuffer(bufStr: string) {
	return Buffer.from(bufStr, 'utf8');
}

export function fromBuffer(obj: Object) {
	return JSON.stringify(obj);
}

/**
 * Error handler for contract API
 *
 * @param {Error} e The error object
 * @param {String} method The function's name
 */
export function handleError(e: any, method: string) {
	logger.error('%s - %s', method, e.message);
	return e;
}

/**
 * Stringify JSON
 *
 * @param {Object} input
 * @returns {String} Stringified JSON
 */
export function prettyJSONString(input: Object) {
	if (!(input.toString())) { return ''; }
	return JSON.stringify(input, null, 2);
}

/**
 * Connect to gateway
 *
 * @param {String} userID The user identity to connect
 * @returns {Gateway} gateway The gateway instance
 */
export async function connectGateway(userID: string) {
	const method = 'connectGateway';
	logger.start(method);

	try {

		// Load the network config
		const fileExists = fs.existsSync(ccpPath);
		if (!fileExists) {
			throw new Error(`Connection profile path not found at file: ${ccpPath}`);
		}

		// Load .yaml config
		const ccpYaml = fs.readFileSync(ccpPath);
		const ccp = yaml.load(ccpYaml as unknown as string);

		const wallet = await Wallets.newFileSystemWallet(walletPath);

		const gateway = new Gateway();
		const gatewayOptions = {
			eventHandlerOptions: {
				strategy: DefaultEventHandlerStrategies.NETWORK_SCOPE_ANYFORTX
			},
			wallet,
			identity: userID,
			clientTlsIdentity: userID,
			discovery: { enabled: true, asLocalhost: AS_LOCALHOST === 'true' }
		};

		// @ts-ignore
		await gateway.connect(ccp, gatewayOptions);

		logger.debug('%s - gateway connected', method);
		return gateway;

	} catch (e: any) {
		logger.error('%s - ', method, e);
		throw e
	}

}

/**
 * Get all methods of an object
 *
 * @param {Object} The object to get methods of
 */
export function getMethods(obj: Object) {
	let properties = new Set()
	let currentObj = obj

	do {
		Object.getOwnPropertyNames(currentObj).map(item => properties.add(item))
	} while ((currentObj = Object.getPrototypeOf(currentObj)))
	return [...properties.keys() as unknown as Array<string>].filter(item => typeof obj[item as keyof Object] === 'function')
}

/**
 * Perform a sleep -- asynchronous wait
 * @param ms the time in milliseconds to sleep for
 */
export function sleep(ms: number) {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Parse input to JSON
 *
 * @param {Buffer} input Buffer to parse
 * @returns {Object} input as JSON
 */
export function prettyJSON(input: any) {
	if (input.toString()) {
		return JSON.parse(input);
	}

	return null;
}

/**
 * @classdec Implementation of a Queue
 * 
 * @ignore
 * @class Queue
 */
export class Queue {

	order: number;
	items: Array<number>;


	constructor() {
		this.order = 0;
		this.items = [];
	}

	/**
	 * Add to queue
	 */
	push() {
		// if (this.mutexLock) {
		// 	await sleep(0.1);
		// 	if (!this.mutexLock) {
		// 		this.mutexLock = true;
		this.items.push(this.order);
		this.order++;
		// this.mutexLock = false;
		return this.order - 1;
		// }
		// }
		// console.log(length);
		// adding element to the queue
		// return this.items.push(element);
	}

	/**
	 * Remove from queue
	 */
	pop() {
		// removing element from the queue
		// returns underflow when called
		// on empty queue
		if (this.isEmpty()) { return -1; }
		return this.items.shift();
	}

	/**
	 * Get front element
	 */
	front() {
		// returns the Front element of
		// the queue without removing it.
		if (this.isEmpty()) { return -1; }
		return this.items[0];
	}

	/**
	 * Query emptiness of queue
	 */
	isEmpty() {
		// return true if the queue is empty.
		return this.items.length === 0;
	}

	/**
	 * Get number of elements
	 */
	count() {
		// return length of queue.
		return this.items.length;
	}

	/**
	 * Print elements
	 */
	printQueue() {
		let str = ' ';
		for (let i = 0; i < this.items.length; i++) { str += this.items[i]; }

		return str;
	}
}

/**
 * Checks if input is JSON
 *
 * @param {} input The input to check
 * @returns {Bool} True if JSON, else false
 */
export function IsJsonString(input: string) {
	try {
		JSON.parse(input);
	} catch (e) {
		return false;
	}
	return true;
}

export function convertTime(UNIX_timestamp: number) {
	let a = new Date(UNIX_timestamp);
	let months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
	let year = a.getFullYear();
	let month = months[a.getMonth()];
	let date = a.getDate();
	let hour = a.getHours().toString().padStart(2, '0');
	let min = a.getMinutes().toString().padStart(2, '0');
	let sec = a.getSeconds().toString().padStart(2, '0');
	let time = date + '-' + month + '-' + year + ' ' + hour + ':' + min + ':' + sec;
	return time;
}

export function getLogger(TYPE: string) {

	let APP_LOGGING: string = process.env.APP_LOGGING!;
	if (process.env.NO_LOG === 'true') APP_LOGGING='';

	/* Logging levels */
	let configLevels = {
		levels: {
			fatal: -1,
			error: 0,
			info: 1,
			warn: 2,
			data: 3,
			debug: 4,
			verbose: 5,
			silly: 6,
		},
		colors: {
			error: 'red',
			info: 'blue',
			debug: 'cyan',
			warn: 'yellow',
			data: 'grey',
			verbose: 'green',
			silly: 'magenta',
			fatal: 'redBG'
		}
	};

	let logger: any;

	let transportOptions = {
		name: '',
		level: '',
		filename: '',
		json: false,
		timestamp: function() {
			return convertTime(Date.now());
		},
		formatter: function(options: any) {
			// - Return string will be passed to logger.
			// - Optionally, use options.colorize(options.level, <string>) to
			//   colorize output based on the log level.
			return options.timestamp() + ' ' +
				config.colorize(options.level, options.level.toUpperCase() + ' ' + '[' + logger.type + ']' + ' ' + '- ') +
				(options.message ? options.message : '') +
				(options.meta && Object.keys(options.meta).length ? '\n\t' + JSON.stringify(options.meta) : '');
		}
	};

	let consoleFormatter = function(options: any) {
		// - Return string will be passed to logger.
		// - Optionally, use options.colorize(options.level, <string>) to
		//   colorize output based on the log level.
		// options.colorize = true;
		// console.log(options)
		return options.timestamp() + ' ' +
			config.colorize(options.level, options.level.toUpperCase() + ' ' + '[' + logger.type + ']' + ' ' + '- ') +
			(options.message ? options.message : '') +
			(options.meta && Object.keys(options.meta).length ? '\n\t' + JSON.stringify(options.meta) : '');
	};

	let fileFormatter = function(options: any) {
		// - Return string will be passed to logger.
		// - Optionally, use options.colorize(options.level, <string>) to
		//   colorize output based on the log level.
		return (options.timestamp() + ' ' + options.level.toUpperCase() + ' ' + '[' + logger.type + ']' + ' ' + '- ' +
			(options.message ? options.message : '') +
			(options.meta && Object.keys(options.meta).length ? '\n\t' + JSON.stringify(options.meta) : ''));
	};

	// interface options {
	// 	transports: any[],
	// 	levels: any[],
	// 	colors: any[],
	// 	method: string,
	// 	type: string
	// }

	let options = {} as winston.LoggerOptions

	let transports = [];

	if (APP_LOGGING) {
		APP_LOGGING = JSON.parse(APP_LOGGING);

		for (const level of Object.keys(APP_LOGGING)) {
			transportOptions.name = level + APP_LOGGING[level];
			transportOptions.level = level;
			if (APP_LOGGING[level] !== 'console') {
				transportOptions.filename = APP_LOGGING[level];
				transportOptions.json = false;
				// options.colors = false;
				transportOptions.formatter = fileFormatter;
				transports.push(new (winston.transports.File)(transportOptions));
			} else {
				options.colors = configLevels.colors;
				transportOptions.filename = '';
				transportOptions.json = false;
				transportOptions.formatter = consoleFormatter;
				transports.push(new (winston.transports.Console)(transportOptions));
			}
			// console.log(level);
		}
	} 
	else {
		transports = [
			new (winston.transports.Console)(transportOptions)
		];
	}

	options.transports = transports;
	logger = new (winston.Logger)(options);

	if (!APP_LOGGING) {
		// console.log((logger.transports))
		Object.keys(logger.transports).forEach(key => {
			logger.transports[key].silent = true
		})
		// [...logger.transports].forEach((t: any) => (t.silent = true));
	}

	logger.start = function(method: string) {
		logger.debug('%s - start', method);
	};

	logger.setType = function(type: string) {
		logger.type = type;
	};

	logger.setLevel = function(level: string) {
		logger.level = level;
	};

	logger.setType(TYPE);
	return logger;
}

/* Logging */
const logger = getLogger(TYPE);