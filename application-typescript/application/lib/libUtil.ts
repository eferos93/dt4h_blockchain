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
import * as _ from 'lodash';

require('dotenv').config();

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
		// Check if the message is an error object and use the error message if available
		const actualMessage = message instanceof Error ? message.message : message;
		return `${colors[level] || ''}${timestamp} [${label}] ${level.toUpperCase()}\x1b[0m: ${actualMessage}`;
	});
	
	const nonColorFormat = format.printf(({ level, message, label, timestamp }) => {
		// Check if the message is an error object and use the error message if available
		const actualMessage = message instanceof Error ? message.message : message;
		return `${timestamp} [${label}] ${level.toUpperCase()}: ${actualMessage}`;
	});
	
	const appLogging = JSON.parse(process.env.FABRIC_APP_LOGGING || '{}');
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
	
	const originalErrorMethod = logger.error.bind(logger);

	logger.error = (message: any, ...meta: any[]): winston.Logger => {
		if (message instanceof Error) {
			return originalErrorMethod(message.message, ...meta);
		} else if (typeof message !== 'string') {
			return originalErrorMethod(JSON.stringify(message), ...meta);
		} else {
			return originalErrorMethod(message, ...meta);
		}
	};

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