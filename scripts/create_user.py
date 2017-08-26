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
from pathlib import Path
import os
import sys
import getopt
import json
## open the file and ensure it contains good user data create a formatted flat user file of all
## valid customers, then zero out the file to ensure we don't load same user data again.
## This script is expecting customer data in the form of:
##
# Takes customer data in JSON format and converts it to Symphony Flat format.
# param:  JSON data in the following format.
# return: Flat Customer record.
class Customer:
    def __init__(self, json_data):
        pass
    def get_flat_customer(self):
        pass

def usage():
    sys.stderr.write('usage: create_user.py [options] [file]\n');
    sys.stderr.write(' -B<barcode> Required. Customer\'s barcode.\n');
    sys.stderr.write(' -j<json_file> Required. Customers\' required input json file.\n');
    sys.stderr.write(' -t Test mode.\n');
    sys.stderr.write(' -x This message.\n');
    sys.exit(1)
            
# Take valid command line arguments.
def main(argv):
    customer_json_file = ''
    customer_id = ''
    is_test = False
    try:
        opts, args = getopt.getopt(argv, "B:j:tx", ['--barcode', '--json='])
    except getopt.GetoptError:
        usage()
    for opt, arg in opts:
        if opt in ( "-j", "--json" ):   # Required and must exist.
            customer_json_file = arg
        elif opt in ( "-B", "--barcode" ): # Required. 
            customer_id = arg
        elif opt in "-t":
            is_test = True
        elif opt in "-x":
            usage()
    # Now simple test to see if user provided all the required data.
    if not customer_id:
        sys.stderr.write('** error, customer barcode is a required parameter and is missing from the command line.\n')
        usage()
        sys.exit(1) 
    if customer_json_file:
        json_data = Path(customer_json_file)
        if json_data.is_file():
            with open(customer_json_file) as json_file:
                lines = json_file.readlines()
                for line in lines:
                    # [{"PHONE":"403-444-1258","USER_FIRST_NAME":"Sylvia","USER_BIRTH_DATE":19610519,"POSTALCODE":"T6M 2M3","CARE_OF":"","CITY_STATE":"Edmonton, AB","EMAIL":"jd@jdlien.com","STREET":"1503 Wellwood Way NW","USER_PIN":"gtk6358","USER_CATEGORY2":"F","USER_LAST_NAME":"Crowley"},{"USER_FIRST_NAME":"Crowley","CARE_OF":"Sylvia Crowley","CITY_STATE":"Edmonton, AB","STREET":"1503 Wellwood Way NW","USER_PIN":"yvy5167","USER_CATEGORY2":"M","PHONE":"403-444-1258","USER_BIRTH_DATE":20050103,"POSTALCODE":"T6M 2M3","CITYONLY":"Edmonton","APARTMENTONLY":"","EMAIL":"jd@jdlien.com","PROVINCEONLY":"AB","ADDRESSONLY":"1503 Wellwood Way NW"}]
                    # The example shows one customer, but child accounts can be added to the JSON array.
                    # Iterate over the array of customer data and pull out each customer.
                    json_customer_data = json.loads(line)
                    for customer_json in json_customer_data:
                        sys.stderr.write('{0}\n'.format(customer_json))
                        customer = Customer()
                    
        else:
            sys.stderr.write('** error, JSON customer data file {0} missing.\n'.format(customer_json_file))
            usage()
            sys.exit(1)
    else:
        sys.stderr.write('** error, JSON customer data file required.\n')
        usage()
        sys.exit(1)
    
    # Done.
    sys.exit(0)

if __name__ == "__main__":
    # import doctest
    # doctest.testmod()
    main(sys.argv[1:])
# EOF
