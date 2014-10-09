#!/bin/sh
# jss_api_mobileConfigProfile.sh
#
# Based on jss_api_id_staticgroup.sh created by Andrew Seago on 07/31/13.
# Modified by Jehan Aziz 5/20/14.
# 
#	This script adds users to the scope of a mobile device configuration profile in your JSS. 
#	Use this at your own risk. It works for me but each enviroment is different. 
#	If you get alot of errors your $JSS_ID_PATH file may need to resaved with textwrangler or textmate. 
#	I found issues when Excel or Word saved the file last
#
# 
# set -x	# DEBUG. Display commands and their arguments as they are executed
# set -v	# VERBOSE. Display shell input lines as they are read.
# set -n	# EVALUATE. Check syntax of the script but dont execute

## Variables
#################################################################################################### 

# Variables used by this script
JSS_XML_INPUT="/tmp/JSS_XML_INPUT.xml" # XML Output to be uploaded to the JSS mobiledeviceconfigurationprofiles API
ConfigProfileID="12" # ID of the iOS Configuration Profile you want to add users to.
# User to add.
thisUser="testUser"

# Variables used by Casper
USERNAME="APIuser" #Username of user with API iOS Configuration Profiles read (GET) and update (PUT) access
PASSWORD="password" #Password of user with API iOS Configuration Profiles read (GET) and update (PUT) access
JSS_URL='https://your.jss.com:8443/JSSResource' # JSS URL of the server you want to run API calls against

## Functions
#################################################################################################### 
# This creates the first part of the XML header 
CreateXML () {
	echo '<?xml version="1.0" encoding="UTF-8" standalone="no"?>' > "$JSS_XML_INPUT"
	echo '<configuration_profile>' >> "$JSS_XML_INPUT"
	echo '<scope>' >> "$JSS_XML_INPUT"
	echo '<limitations>' >> "$JSS_XML_INPUT"
	echo '<users>' >> "$JSS_XML_INPUT"
	echo "$1" >> "$JSS_XML_INPUT"
	echo '</users>' >> "$JSS_XML_INPUT"
	echo '</limitations>' >> "$JSS_XML_INPUT"
	echo '</scope>' >> "$JSS_XML_INPUT"
	echo '</configuration_profile>' >> "$JSS_XML_INPUT"

# Call the UploadUser function
	UploadUser
}

# This uploads the $JSS_XML_INPUT file to the JSS
function UploadUser () {
	curl -v $JSS_URL/mobiledeviceconfigurationprofiles/id/$ConfigProfileID --user "$USERNAME:$PASSWORD" -X PUT -T $JSS_XML_INPUT
}

## Script
#################################################################################################### 
# Script Action 1

# Get the current list of users scoped to this iOS Configuration Profiles.
userList=`curl -v $JSS_URL/mobiledeviceconfigurationprofiles/id/$ConfigProfileID/subset/scope --user "$USERNAME:$PASSWORD" -X GET | xpath //configuration_profile/scope/limitations/users/user`

# Add user to the list.
newList="$userList<user><name>$thisUser</name></user>"

# Call the CreateXML function passing in the new list of users.
CreateXML $newList