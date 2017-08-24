#!/bin/bash
##################################################################################
#
# Reads and reports the next user ID. 
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
#          0.1 - Working version. 
#          0.0 - Dev. 
#
##############################################################################
VERSION="0.1"
### This script will read the last user ID, store the next value back in a file
### print it to STDOUT and then exits.
### Source of the next user ID number.
### '21221900000007'
export NEXT_ID_FILE=./nextcustomerid
if [ -s "$NEXT_ID_FILE" ]; then
	# read the next id file, and save that value for printing to STDOUT.
	current_id=$(cat "$NEXT_ID_FILE" | pipe.pl -L-1 -tc0 -nc0)
	# Take the current ID and use pipe.pl to increment the value.
	next_id=$(echo "$current_id" | pipe.pl -1c0)
	# If that failed then echo a message to STDERR and echo '-1' to STDOUT.
	if [[ -z "${next_id// }" ]]; then
		echo "** error, could not find $NEXT_ID_FILE **" >&2
		echo "-1"
	else # write the next ID to the nextcustomerid clobbering the existing file.
		echo "$next_id" > $NEXT_ID_FILE
		# Echo the final value to STDERR.
		echo $current_id
	fi
else
	# report that the nextcustomerid file couldn't be found and the ILS admin 
	# needs to find the last highest customer ID with the prefix '$CARD_PREFIX'
	# and put that in a file called '$NEXT_ID_FILE'. See above.
	echo "** error, could not find $NEXT_ID_FILE **" >&2
	echo "-1"
fi
# EOF
