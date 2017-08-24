#!/usr/bin/env python
##################################################################################
#
# Creates and loads users based on data in file /home/ilsadmin/create_user/scripts. 
#
# Fetch the set of new users from the ILS, then zero out the file on success.
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
# Copyright (c) Thu Feb 23 16:22:30 MST 2017
# Rev: 
#          0.0 - Dev. 
#
##############################################################################
## open the file and ensure it contains good user data create a formatted flat user file of all
## valid customers, then zero out the file to ensure we don't load same user data again.
## This script is expecting customer data in the form of:
## 
# Takes customer data in JSON format and converts it to Symphony Flat format.
# param:  JSON data in the following format.
# return: Flat Customer record.
class FlatCustomer:
    def __init__(self, json_customer_data):
        pass
    def get_flat_customer(self):
        pass
        
class CustomerLoader:
    def __init__(self):
        pass
    def parse(self, customer_json_file): # Check for errors in the file.
        pass
    # Takes test value to not run against the ILS.
    # return: True if the load was successful and false otherwise.
    def load(self, is_test=True):
        pass
    # Zero's out the customer file so there are no repeat loads.
    def zero_file(self, customer_json_file):
        pass
        
# Take valid command line arguments -b, and -x.
def main(argv):
    customer_json_file = ''
    customer_flat_file = ''
    is_test = False
    try:
        opts, args = getopt.getopt(argv, "b:o:tx", ['--bulk_add=', '--out_file='])
    except getopt.GetoptError:
        usage()
    for opt, arg in opts:
        if opt in ( "-b", "--bulk_add" ):   # must exist.
            customer_json_file = arg
        elif opt in ( '-o', '--out_file' ): # Automatically clobbered.
            customer_flat_file = arg
        elif opt in ( 't' ):
            sys.stderr.write('test mode enabled.\n')
            is_test = True
        elif opt in "-x":
            usage()
    # Now simple test to see if user provided all the required data.
    if customer_json_file && customer_flat_file:
        print 'good to go.'
    else:
        sys.stderr.write('no output file name provided. An output file name is used by another process.\n');
        sys.exit(1)
    customer_loader = CustomerLoader()
    customer_loader.parse(customer_json_file) # Check for errors in the file.
    if customer_loader.load(is_test):
        customer_loader.zero_file(customer_json_file)
    # Done.
    sys.exit(0)

if __name__ == "__main__":
    # import doctest
    # doctest.testmod()
    main(sys.argv[1:])
# EOF
