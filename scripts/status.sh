#!/bin/bash
##################################################################################
#
# Tests if the ILS is available. 
#
#    Copyright (C) 2017  Andrew Nisbet
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
# Author:  Andrew Nisbet, Edmonton Public Library
# Copyright (c) Thu Aug 24 14:05:32 MDT 2017
# Rev: 
#          0.0 - Dev. 
#
##############################################################################
VERSION="0.0"
### This script will send a seluser request, which will test pathing to all SirsiDynix executables.
### All calls must have explicit exit code to trigger the node.js exec.on('exit', function(code)) to run.
USER_ID=21221012345678
TEST_ILS="sirsi@edpl-t.library.ualberta.ca"  # Test server is default ILS to write to.
PROD_ILS="sirsi@eplapp.library.ualberta.ca"  # Production server is default ILS to write to.
SERVER="$TEST_ILS"                           # Current server target.
USER_KEY=$(echo "$USER_ID" | ssh $SERVER 'cat - | seluser -iB' 2>/dev/null)
# If that failed then echo a message to STDERR and echo '-1' to STDOUT.
if [[ -z "${USER_KEY// }" ]]; then
	echo "** error, failed to find $USER_ID on $SERVER **" >&2
	echo "-1"
	exit 1  # Failed to read nextcustomerid file.
else # write the next ID to the nextcustomerid clobbering the existing file.
	echo "0"
	exit 0 # Success
fi
# EOF
