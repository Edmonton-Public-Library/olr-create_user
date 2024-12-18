#!/usr/bin/env python3
##################################################################################
#
# Creates and loads users based on data in file /home/ilsadmin/create_user/scripts.
#
# Fetch the set of new users from the ILS, then zero out the file on success.
#    Copyright (C) 2017-2023  Andrew Nisbet
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
# Created: Thu Feb 23 16:22:30 MST 2017
# Rev:
#          0.6 - Changed EPL_NOVIDG to EPL_SELF and EPL_JNOVG to EPL_SELFJ.
#          0.5 - Removed preferred name since upgrading to Symphony 4.0.
#          0.4 - Changed EPL_ADULT to EPL_NOVIDG and EPL_JUV to EPL_JNOVG.
#          0.3 - Project converted to use python3.
#          0.2 - Remove USER_CATEGORY2.
#          0.1 - Added missing USER_CATEGORY2, USER_BIRTH_DATE, and reordered for
#                easy parsing and adding to the duplicate user database.
#          0.0 - Dev.
#
##############################################################################
from pathlib import Path
import datetime
import os
import sys
import getopt
import json
import io
## open the file and ensure it contains good user data create a formatted flat user file of all
## valid customers, then zero out the file to ensure we don't load same user data again.
## This script is expecting customer data in the form of:
##
# Takes customer data in JSON format and converts it to Symphony Flat format.
# param:  JSON data in the following format.
# return: Flat Customer record.
class Customer:
    def __init__(self, data):
        self.json = data
        # JSON format:
        # {
        # 'USER_LAST_NAME': 'Crowley',
        # 'CITYONLY': 'Edmonton',
        # 'ADDRESS': {'STREET': '1503 Wellwood Way NW', 'POSTALCODE': 'T6M 2M3', 'CITY_STATE': 'Edmonton, AB'},
        # 'USER_FIRST_NAME': 'Edward',
        # 'USER_PIN': 'mtj8528',
        # 'ADDRESSONLY': '1503 Wellwood Way NW',
        # 'EMAIL': 'jd@jdlien.com',
        # 'PHONE': '403-444-1258',
        # 'USER_CATEGORY2': 'M',
        # 'CARE_OF': 'Sylvia Crowley',
        # 'APARTMENTONLY': '',
        # 'PROVINCEONLY': 'AB',
        # 'USER_BIRTH_DATE': 20090918,
        # 'USER_AGE': 7,
        # 'USER_CATEGORY1': 'ERCS',
        # 'NOTE': 'Any requested change to this account must be referred to the branch Community Librarian or Manager'
        # }
        # Convert the customer to flat format.
        # *** DOCUMENT BOUNDARY ***
        # FORM=LDUSER
        # .USER_FIRST_NAME.   |aGxxx
        # .USER_ACCESS.   |aPUBLIC
        # .USER_STATUS.   |aOK
        # .USER_CHG_HIST_RULE.   |aALLCHARGES
        # .USER_ID.   |a21000008600999
        # .USER_ROUTING_FLAG.   |aY
        # .USER_CATEGORY5.   |aECONSENT
        # .USER_ENVIRONMENT.   |aPUBLIC
        # NOTE: The preferred name is being dropped since upgrading to Symphony 4.0. May 02, 2024.
        # .USER_PREFERRED_NAME.   |aAXXXXX, GXXX
        # .USER_PREF_LANG.   |aENGLISH
        # .USER_PIN.   |a2913
        # .USER_PROFILE.   |aEPL_METRO
        # .USER_LAST_NAME.   |aAxxxxxx
        # .USER_LIBRARY.   |aEPLMNA
        # .USER_PRIV_EXPIRES.   |a20180719
        # .USER_PRIV_GRANTED.   |a20170826
        # .USER_ADDR1_BEGIN.
        # .POSTALCODE.   |aH0H 0H0
        # .PHONE.   |a403-nnn-nnnn
        # .STREET.   |aRr 7 D
        # .CITY/STATE.   |aPonoka, AB
        # .EMAIL.   |axxxxxxxx@hotmail.com
        # .USER_ADDR1_END.
        # .USER_CATEGORY1.   |aERCS
        # .USER_XINFO_BEGIN.
        # .NOTE. |aAny requested change to this account must be referred to the branch Community Librarian or Manager
        # .USER_XINFO_END.
        #
        self.expire = 'NEVER'
        p_date = datetime.datetime.now()
        self.today = p_date.strftime("%Y%m%d")
        # Test for user age
        if self.json['USER_AGE'] < 18:
            self.profile = 'EPL_SELFJ'
        else:
            self.profile = 'EPL_SELF'
    def __repr__(self):
        self.__str__()
    def __str__(self):
        flat_customer = """*** DOCUMENT BOUNDARY ***
FORM=LDUSER
.USER_ID.   |a{USER_ID}
.USER_ACCESS.   |aPUBLIC
.USER_STATUS.   |aOK
.USER_CHG_HIST_RULE.   |aCIRCRULE
.USER_MAILINGADDR.   |a1
.USER_ROUTING_FLAG.   |aY
.USER_CATEGORY5.   |aECONSENT
.USER_ENVIRONMENT.   |aPUBLIC
.USER_FIRST_NAME.   |a{USER_FIRST_NAME}
.USER_LAST_NAME.   |a{USER_LAST_NAME}
.USER_PREF_LANG.   |aENGLISH
.USER_PIN.   |a{USER_PIN}
.USER_PROFILE.   |a{USER_PROFILE}
.USER_LIBRARY.   |aEPLMNA
.USER_PRIV_EXPIRES.   |a{USER_PRIV_EXPIRES}
.USER_PRIV_GRANTED.   |a{USER_PRIV_GRANTED}
.USER_BIRTH_DATE.   |a{USER_BIRTH_DATE}
.USER_ADDR1_BEGIN.
.CARE/OF.   |a{CARE_OF}
.EMAIL.   |a{EMAIL}
.POSTALCODE.   |a{POSTALCODE}
.PHONE.   |a{PHONE}
.STREET.   |a{STREET}
.CITY/STATE.   |a{CITY_STATE}
.USER_ADDR1_END.""".format(
            USER_ID=self.json['USER_ID'],
            USER_FIRST_NAME=self.json['USER_FIRST_NAME'],
            USER_LAST_NAME=self.json['USER_LAST_NAME'],
            USER_PIN=self.json['USER_PIN'],
            USER_PROFILE=self.profile,
            USER_PRIV_EXPIRES=self.expire,
            USER_PRIV_GRANTED=self.today,
            USER_BIRTH_DATE=str(self.json['USER_BIRTH_DATE']).replace("-", ""),
            CARE_OF=self.json['CARE_OF'],
            EMAIL=self.json['EMAIL'],
            POSTALCODE=self.json['ADDRESS']['POSTALCODE'],
            PHONE=self.json['PHONE'],
            STREET=self.json['ADDRESS']['STREET'],
            CITY_STATE=self.json['ADDRESS']['CITY_STATE']
        )
        if 'USER_CATEGORY1' in self.json:
            flat_customer = """{FLAT_CUSTOMER}
.USER_CATEGORY1.   |a{USER_CATEGORY1}""".format(
            FLAT_CUSTOMER=flat_customer,
            USER_CATEGORY1=self.json['USER_CATEGORY1'],
            )
        if 'USER_CATEGORY2' in self.json:
            flat_customer = """{FLAT_CUSTOMER}
.USER_CATEGORY2.   |a{USER_CATEGORY2}""".format(
            FLAT_CUSTOMER=flat_customer,
            USER_CATEGORY2=self.json['USER_CATEGORY2'],
            )
        if 'NOTE' in self.json:
            flat_customer = """{FLAT_CUSTOMER}
.USER_XINFO_BEGIN.
.NOTE. |a{NOTE}
.USER_XINFO_END.""".format(
            FLAT_CUSTOMER=flat_customer,
            NOTE=self.json['NOTE'],
            )
        return flat_customer

def usage():
    sys.stderr.write('usage: create_user.py [options] [file]\n');
    sys.stderr.write(' -j<json_file> Required. Customers\' required input json file.\n');
    sys.stderr.write(' -t Test mode.\n');
    sys.stderr.write(' -x This message.\n');
    sys.exit(1)

# Take valid command line arguments.
def main(argv):
    customer_json_file = ''
    is_test = False
    try:
        opts, args = getopt.getopt(argv, "j:tx", ['--json='])
    except getopt.GetoptError:
        usage()
    for opt, arg in opts:
        if opt in ( "-j", "--json" ):   # Required and must exist.
            customer_json_file = arg
        elif opt in "-t":
            is_test = True
        elif opt in "-x":
            usage()
    # Now simple test to see if user provided all the required data.
    if customer_json_file:
        json_data = Path(customer_json_file)
        if json_data.is_file():
            with open(customer_json_file) as json_file:
                for line in json_file:
                    # [{"PHONE":"403-444-1258","USER_FIRST_NAME":"Sylvia","USER_BIRTH_DATE":19610519,"POSTALCODE":"T6M 2M3","CARE_OF":"","CITY_STATE":"Edmonton, AB","EMAIL":"jd@jdlien.com","STREET":"1503 Wellwood Way NW","USER_PIN":"gtk6358","USER_CATEGORY2":"F","USER_LAST_NAME":"Crowley"},{"USER_FIRST_NAME":"Crowley","CARE_OF":"Sylvia Crowley","CITY_STATE":"Edmonton, AB","STREET":"1503 Wellwood Way NW","USER_PIN":"yvy5167","USER_CATEGORY2":"M","PHONE":"403-444-1258","USER_BIRTH_DATE":20050103,"POSTALCODE":"T6M 2M3","CITYONLY":"Edmonton","APARTMENTONLY":"","EMAIL":"jd@jdlien.com","PROVINCEONLY":"AB","ADDRESSONLY":"1503 Wellwood Way NW"}]
                    # The example shows one customer, but child accounts can be added to the JSON array.
                    # Iterate over the array of customer data and pull out each customer.
                    json_customer_data = json.loads(line)
                    for customer_json in json_customer_data:
                        # sys.stderr.write('{0}\n'.format(customer_json))
                        customer = Customer(customer_json)
                        print(customer)
                        #sys.stdout.write('{0}'.format(customer))
                        # sys.exit(0)
        else:
            sys.stderr.write('** error, JSON customer data file {0} missing.\n'.format(customer_json_file))
            usage()
            sys.exit(-1)
    else:
        sys.stderr.write('** error, JSON customer data file required.\n')
        usage()
        sys.exit(-1)

    # Done.
    sys.exit(0)

if __name__ == "__main__":
    # import doctest
    # doctest.testmod()
    main(sys.argv[1:])
# EOF
