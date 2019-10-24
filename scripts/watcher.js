#!/usr/bin/env node

'use strict';

const fs = require('fs');
const exec = require('child_process').exec;

const folder = process.argv[2] || `${process.env.HOME}/OnlineRegistration/olr-create_user/incoming`; // default if one is not specified
const runscript = process.argv[3] || `${process.env.HOME}/OnlineRegistration/olr-create_user/scripts/convert_user.sh`

const usage = function() {
  console.log(`
    =============================================================================
    node watcher <path to the folder to be monitored> <path to the script to run>

    if <path to the folder to be monitored> is not speified, it's default to
    '/home/ilsadmin/OnlineRegistration/olr-create_user/incoming'

    if <path to the script to run> is not specified, it's default to
    '/home/ilsadmin/OnlineRegistration/olr-create_user/scripts/convert_user.sh'

    e.g.
    node watcher $HOME/OnlineRegistration/olr-create_user/incoming $HOME/OnlineRegistration/olr-create_user/scripts/convert_user.sh
  `);
}

const errorHandler = function(error, message) {
  if (error) {
    console.log(`${JSON.stringify(message)}:
      ${JSON.stringify(error)}
    `);
    usage();
    process.exit(1);
  }
}

const validate = function(path) {
  const message = `Incorrect path: ${path}`
  try {
    const stats = fs.statSync(path);
    errorHandler(stats? null : `NOT FOUND`, message);
  } catch(ex) {
    errorHandler(ex,message);
  }
}

const start = function() {

  validate(folder);
  validate(runscript);

  console.log(`Start monitoring folder: ${folder}`);

  fs.watch(folder).on('change', (eventType, filename) => {
  	console.log(`${new Date()} On change: ${JSON.stringify(eventType)} - ${JSON.stringify(filename)}`);
  	if (eventType === 'change' && filename.endsWith('.data')) {
  		setImmediate(() => {
  			exec(`sh ${runscript}`, (err, stdout, stderr) => {
          if (err) {
            errorHandler(err, stderr);
            // console.log(error);
            // console.log(stderr);
            // process.exit(1);
          } else {
            console.log(stdout);
            console.log(stderr);
          }
  			}); // exec
  		}); // setImmediate
  	} // if
  }); // onChange
}

start();
