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
import winston, { format, transport } from 'winston';

import * as process from 'process';
import * as path from 'path';
import * as yaml from 'js-yaml';
import * as fs from 'fs';
import * as _ from 'lodash';

import { Gateway, Wallets, DefaultEventHandlerStrategies } from 'fabric-network';
const config = winston.config;
require('dotenv').config();

/* Env */
const walletPath: string = path.join(process.env.FABRIC_WALLET_PATH!);
const ccpPath: string = path.resolve(process.env.FABRIC_CCP_PATH!);
const AS_LOCALHOST: string = process.env.FABRIC_AS_LOCALHOST!.toLowerCase()

export function toBuffer(bufStr: string) {
	return Buffer.from(bufStr, 'utf8');
}

export function fromBuffer(obj: Object) {
	return JSON.stringify(obj);
}

export function bufferToJson(buf: Uint8Array) {
	return JSON.parse(Buffer.from(buf).toString('utf-8'))
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



export const getLogger = (type: string) => {
	const { combine, timestamp, printf, colorize } = format;

	// Custom logging levels
	const loggingLevels = {
		fatal: 0,
		error: 1,
		warn: 2,
		info: 3,
		debug: 4,
		verbose: 5,
		silly: 6,
	};

	const colors = {
		'debug': "\x1b[36m",
		'error': "\x1b[31m",
		'fatal': "\x1b[31m",
		'warn': "\x1b[33m",
		'info': "\x1b[34m"
	};

	winston.addColors(colors); // Add custom colors

	const myFormat = format.printf(({ level, message, label, timestamp }) => {
		return `${colors[level] || ''}${timestamp} [${label}] ${level.toUpperCase()}\x1b[0m: ${message}`;
	});

	const nonColorFormat = format.printf(({ level, message, label, timestamp }) => {
		return `${timestamp} [${label}] ${level.toUpperCase()}: ${message}`;
	});
	
	const appLogging = JSON.parse(process.env.APP_LOGGING || '{}');
	const transports: winston.transport[] = [];

	for (const level in loggingLevels) {
		if (appLogging[level] === 'console') {
			transports.push(new winston.transports.Console({
				format: combine(timestamp(), myFormat), // Apply colorize
				level: level,
			}));
		} else {
			transports.push(new winston.transports.File({
				filename: `logs/${level}.log`,
				level: level,
				format: combine(timestamp(), nonColorFormat),
			}));
		}
	}

	const logger = winston.createLogger({
		levels: loggingLevels,
		defaultMeta: { label: type },
		transports: transports
	});

	return logger
}

export const isEqualCommonProperties = (obj1, obj2) => {

	for (const key of Object.keys(obj1)) {
		if (!obj2.hasOwnProperty(key)) {
			continue
		}

		if (typeof obj1[key] === 'object') {
			if (!isEqualCommonProperties(obj1[key], obj2[key])) {
				return false
			}
			continue
		}

		if (!(_.isEqual(obj1[key], obj2[key]))) {
			return false
		}
	}

	return true
}

/* Logging */
const logger = getLogger(TYPE);