#!/usr/bin/env node

'use strict';

const fs = require('fs');
const chokidar = require('chokidar');
const exec = require('child_process').exec;
const path = require('path');

const files = process.argv[2] || `${process.env.HOME}/OnlineRegistration/olr-create_user/incoming/*.data`; // default if one is not specified
const runscript = process.argv[3] || `${process.env.HOME}/OnlineRegistration/olr-create_user/scripts/convert_user.sh`

const usage = function() {
  console.log(`
    =============================================================================
    node watcher <path to the files to be monitored> <path to the script to run>

    if <path to the folder to be monitored> is not speified, it's default to
    '/home/ilsadmin/OnlineRegistration/olr-create_user/incoming/*.data'

    if <path to the script to run> is not specified, it's default to
    '/home/ilsadmin/OnlineRegistration/olr-create_user/scripts/convert_user.sh'

    e.g.
    node watcher $HOME/OnlineRegistration/olr-create_user/incoming/*.data $HOME/OnlineRegistration/olr-create_user/scripts/convert_user.sh
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

  const folder = path.parse(files).dir;
  console.log(`Folder to monitor: ${folder}`);
  validate(folder);

  console.log(`Script to run: ${runscript}`);
  validate(runscript);

  console.log(`Start monitoring files: ${files}`);

  // Use chokidar instead of fs to avoid receiving duplicated events
  const watcher = chokidar.watch(`${files}`);
  watcher
    .on('add', (path) => {
      console.log(`${new Date().toISOString()}: File ${path} has been added`);
  		exec(`${runscript} ${path}`, (err, stdout, stderr) => {
        if (err) {
          // stop watching
          watcher.close();
          errorHandler(err, stderr);
        } else {
          console.log(stdout);
          console.log(stderr);
        }
  		}); // exec
    }) // onAdd
    .on('change', (path) => console.log(`${new Date().toISOString()}: File ${path} has been changed`))
    .on('unlink', (path) => console.log(`${new Date().toISOString()}: File ${path} has been removed`));
}

start();
