#!/bin/bash
#
# Author: Johan McGwire - Yohan @ Macadmins Slack - Johan@McGwire.tech
#
# Description: This script Extension attribute reports if the assigned user in JAMF has a secureToken

# Checking for the policy receipt
if [[ -f "/Library/Contoso/Receipts/.AssignedUserGivenToken" ]]; then

    # If receipt exsits then there is no reason to go on, just report true
    echo "<result>True</result>"
    exit 0

# Check to see if some other method ended up with the user getting a secure token
else
    # Saving the api information
    API_USER="API_ACCOUNT_USERNAME"
    API_PASSWORD="API_ACCOUNT_PASSWORD"

    # Getting the serial number
    serialNum=`ioreg -l | awk '/IOPlatformSerialNumber/ { print $4;}' | sed 's/"//g'`

    # Getting the JSS URL
    JSSURL=`defaults read /Library/Preferences/com.jamfsoftware.jamf.plist jss_url`

    # Getting the JAMF Assigned Username
    assignedUser=`/usr/bin/curl -s -k -u "$API_USER:$API_PASSWORD" -X GET -H "accept: application/xml" "${JSSURL}JSSResource/computers/serialnumber/${serialNum}" | xmllint --xpath '//computer/location/username/text()' -`
    # Making sure the assigned user is not null and in the secureTokenList
    if [[ "$assignedUser" != "" && ! $(sysadminctl -secureTokenStatus "$assignedUser" 2>&1 | grep -v "ENABLED") ]]; then
        echo "<result>True</result>"
    else
        echo "<result>False</result>"
    fi
fi

# Exiting with zero becuase it's an EA and I don't care about the return code
exit 0
