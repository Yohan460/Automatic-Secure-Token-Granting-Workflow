#!/bin/bash
#
# Author: Johan McGwire - Yohan @ Macadmins Slack - Johan@McGwire.tech
#
# Description: This script prompts the user for their password, then uses that to enable the user account on the machine with a secureToken utilizing the admin credentials

# Checking if the regular account username was sent through the a JAMF Parameter
if [ -z $3 ];then
    read -p "Please enter the account username: " addUser
else 
    addUser=$3
fi

# Checking if the Admin Account Username was sent through the a JAMF Parameter
if [ -z $4 ];then
    read -p "Please enter the admin username: " adminUser
else 
    adminUser=$4
fi

# Checking if the Admin Account Password was sent through the a JAMF Parameter
if [ -z $5 ];then
    read -p "Please enter admin password: " adminPass
else 
    adminPass=$5
fi

# Reprompting in case the user inputs an incorrect password
sysadminctlOutput=""
while [[ $sysadminctlOutput == *"Incorrect password"* || $sysadminctlOutput == "" ]]; do
    # Prompting for the user to enter their password
    if [[ ! -f /Library/Contoso/Receipts/.SecureTokenPromptCancelled ]]; then
        read -r -d '' applescriptCode <<'EOF'
            set dialogText to text returned of (display dialog "Contoso Corp is requiring FileVault disk encryption on faculty/staff primary computers to enhance data security. If you have questions please contact the Help Desk at +1(981) 867-5309.

Please enter your password to enable your account for FileVault encryption:" default answer "" buttons {"Cancel", "Enable"} default button "Enable" with hidden answer)
return dialogText
EOF
    else
        read -r -d '' applescriptCode <<'EOF'
            set dialogText to text returned of (display dialog "Contoso Corp is requiring FileVault disk encryption on faculty/staff primary computers to enhance data security. If you have questions please contact the Help Desk at +1(981) 867-5309.

Please enter your password to enable your account for FileVault encryption:" default answer "" buttons {"Enable"} default button "Enable" with hidden answer)
return dialogText
EOF
    fi
   
    USER_ID=$(/usr/bin/id -u “$addUser”)
    addUserPass=$(/bin/launchctl asuser “$USER_ID” osascript -e "$applescriptCode" || touch /Library/Contoso/Receipts/.SecureTokenPromptCancelled && exit 0)

    # Enabling the secure token for the admin account
    sysadminctlOutput=$(sysadminctl -secureTokenOn $addUser -password $addUserPass -adminUser $adminUser -adminPassword $adminPass 2>&1)
    returnCode=$?
    echo "$sysadminctlOutput"
done

# Checking for any other errors and changing the return code if there are any
if [[ $sysadminctlOutput != *"Done"* ]]; then
    returnCode=1
else
    touch /Library/Contoso/Receipts/.AssignedUserGivenToken
fi

# Exiting and returning the policy call code
exit $returnCode
