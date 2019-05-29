#!/bin/bash
#
# Author: Johan McGwire - Yohan @ Macadmins Slack - Johan@McGwire.tech
#
# Description: Upon initial configuration this enables the hidden administrator account and removes the token from the management account if necessary

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

# Checking if the management Account Username was sent through the a JAMF Parameter
if [ -z $6 ];then
    read -p "Please enter the management username: " managementUser
else 
    managementUser=$6
fi

# Checking if the management Account Password was sent through the a JAMF Parameter
if [ -z $7 ];then
    read -p "Please enter management password: " managementPass
else 
    managementPass=$7
fi

# Checking to see if the management account is enabled, removing newlines using sed from the fdesetup list
if ! fdesetup list | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/ /g' | grep -v "$managementUser"; then
    
    echo "Management Account detected as enabled"

    # Enabling the secure token for the admin account
    sysadminctl -secureTokenOn $adminUser -password $adminPass -adminUser $managementUser -adminPassword $managementPass

    # Attempting to remove the secure token from the account
    if [[ $(sysadminctl -secureTokenOff $managementUser -password $managementPass -adminUser $adminUser -adminPassword $adminPass 2>&1 | grep -v "Done") ]]; then
        
        # If the removal fails using sysadminctl then nuke the account to get rid of the token
        jamf policy -event recreateManagementAccount
    fi
else

    echo "Management Account NOT detected as enabled"

    # Enabling the secure token for the admin account
    sysadminctl -secureTokenOn $adminUser -password $adminPass -adminUser $adminUser -adminPassword $adminPass
fi

# Exiting and returning the policy call code
exit $?