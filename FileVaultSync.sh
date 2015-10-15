#!/bin/sh

####################################################################################################
#
# Copyright (c) 2013, JAMF Software, LLC. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# * Neither the name of the JAMF Software, LLC nor the
# names of its contributors may be used to endorse or promote products
# derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
####################################################################################################
#
# Description
# This script was designed to enable the currently logged in user's account the ability to unlock
# a drive that was originally encrypted with the management account using a policy from the JSS.
#   The script will prompt the user for their credentials.
#   
#   This script was designed to be run via policy at login or via Self Service. The encryption
#   process must be fully completed before this script can be successfully executed. 
#
####################################################################################################
# 
# HISTORY
#
#   -Created by Bryson Tyrrell on November 5th, 2012
#   -Updated by Sam Fortuna on July 31, 2013
#   -Improved Error Handling
#   -Added check for admin user as a FV user and removing the current logged in user from FileVault 2 so that script can be used to work around the FV password being out of sync with the login password. By Jehan B Aziz March 12, 2015
#   -Added loop to handle incorrect passwords and function for cleanup. By Jehan B Aziz March 23, 2015
#
####################################################################################################
#
## Self Service policy to remove and then re-add the logged in user to the enabled list
## of FileVault 2 users.

### Functions

## clean up function
function cleanUp {
if [[ -e /tmp/fvenable.plist ]]; then
    srm /tmp/fvenable.plist
fi
}

## Pass the credentials for an admin account that is authorized with FileVault 2
adminName=$4
adminPass=$5

if [ "${adminName}" == "" ]; then
echo "Username undefined. Please pass the management account username in parameter 4"
exit 1
fi

if [ "${adminPass}" == "" ]; then
echo "Password undefined. Please pass the management account password in parameter 5"
exit 2
fi

## Make sure the admin account is already enabled for FileVault 2
userCheck=`fdesetup list | grep -o "\b$adminName\b"`
echo "Admin is $adminName."
echo "FileVault user that matches $adminName is $userCheck."
if [ "${userCheck}" != "${adminName}" ]; then
echo "The admin account is not authorized with FileVault 2."
osascript -e 'Tell application "System Events" to display dialog "The NGST admin account is not configured properly. Please contact the Help Desk." with title "Password Sync Error" with text buttons {"Ok"} default button 1'
exit 6
fi

## Get the logged in user's name
userName=$3
echo "Logged in user is $3."

## Remove the current user from FileVault 2
fdesetup remove -user $userName

## This first user check sees if the logged in account is already authorized with FileVault 2
userCheck=`fdesetup list | grep -o "\b$userName\b"`
if [ "${userCheck}" == "${userName}" ]; then
echo "This user is already added to the FileVault 2 list."
exit 3
fi

## Check to see if the encryption process is complete
encryptCheck=`fdesetup status`
statusCheck=$(echo "${encryptCheck}" | grep "FileVault is On.")
expectedStatus="FileVault is On."
if [ "${statusCheck}" != "${expectedStatus}" ]; then
echo "The encryption process has not completed, unable to add user at this time."
echo "${encryptCheck}"
exit 4
fi

## Set counter for loop
COUNTER=0

### Lopp up to 3 times if the wrong password is entered.
while [ $COUNTER -lt 3 ]; do
echo "The counter is $COUNTER"

## Get the logged in user's password via a prompt
echo "Prompting ${userName} for their login password."
userPass="$(osascript -e 'Tell application "System Events" to display dialog "Please enter your current login password:" default answer "" with title "Login Password" with text buttons {"Ok"} default button 1 with hidden answer' -e 'text returned of result')"

echo "Adding $userName to FileVault 2 list."

# create the plist file:
echo '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>Username</key>
<string>'$4'</string>
<key>Password</key>
<string>'$5'</string>
<key>AdditionalUsers</key>
<array>
    <dict>
        <key>Username</key>
        <string>'$userName'</string>
        <key>Password</key>
        <string>'$userPass'</string>
    </dict>
</array>
</dict>
</plist>' > /tmp/fvenable.plist

# now enable FileVault
fdesetup add -inputplist < /tmp/fvenable.plist

## This second user check sees if the logged in account was successfully added to the FileVault 2 list
userCheck=`fdesetup list | grep -o "\b$userName\b"`
echo "User check is $userCheck."
echo "User name is $userName."
if [ "${userCheck}" != "${userName}" ]; then
echo "Failed to add user to FileVault 2 list."
osascript -e 'Tell application "System Events" to display dialog "Failed to sync your passwords. This may be due to an incorrectly entered password. Running Password Sync agan." with title "Password Sync Error" with text buttons {"Ok"} default button 1'
else
echo "${userName} has been added to the FileVault 2 list."
osascript -e 'Tell application "System Events" to display dialog "Password Sync was sucessful!" with title "Password Sync Complete" with text buttons {"Ok"} default button 1'
cleanUp
exit 0
fi

let COUNTER=COUNTER+1 
cleanUp
done

echo "Failed to add user to FileVault 2 list."
osascript -e 'Tell application "System Events" to display dialog "WARNING! Failed to sync your passwords. Please contact the Help Desk immediately for assistance." with title "Password Sync Error" with text buttons {"Ok"} default button 1'

exit 5