# Automatic-Secure-Token-Granting-Workflow
This workflows allows for the automatic granting of secure tokens to the Jamf Pro Assigned user on a machine utilizing a known SecureToken Enabled administrator account

## Endgame
To have a user driven, automatic method of enabling the primary user on a machine with a SecureToken and have FileVault enabled with a method of enabling future accounts

## Reasoning
With the Apple implementation of giving SecureTokens to accounts that do not have them, it requires the user to enter the credentials to the SecureToken enabled administrator account. This is obviously something that a system administrator would not want a user to know or do. Therefore we need a way of placing the SecureToken environment into a known state with known credentials be used in an automatically trigged method for assigning the user a SecureToken. Then reporting on that success.

## Step 1 - Disabling the Apple SecureToken Prompt

For this first steps let's get rid of that pesky Apple SecureToken prompt since your users won't know your admin password. This can be done by using a custom config profile with the following information
```
Custom Settings
	Domain: com.apple.mcx
	Contents: cachedaccounts.askForSecureTokenAuthBypass=true
```


## Step 2 - Reporting on general SecureToken Status
To setup some smart group scopings for Step 3 and 4 we must start retrieving the SecureToken list from the endpoint. This takes the form of an Extension Attribute. This takes the form of the following properties

* Name - `SecureToken Status`
* Data Type - `String`
* Input Type - `Script`
* Script - [`SecureTokenStatusEA.sh`](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/SecureTokenStatusEA.sh)

## Step 3 - Reporting on the Assigned User SecureToken Status
Due to the limitation of not being able to do any funky regex on the Jamf pro side to check if the assigned user has a token. Therefore we need an EA. This EA uses an API call with Jamf to get the assigned user username, then checks that against the SecureToken enabled users on the machine. We can't use script parameters to get the API username and password unfortunately because it is an EA. The contents of the EA are below

* Name - `Assigned User has SecureToken	`
* Data Type - `String`
* Input Type - `Script`
* Script - [`assignedUserFV2EnabledEA.sh`](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/assignedUserFV2EnabledEA.sh)

Note: You will need to add your Jamf Pro Server API username and password to the script for it to function

## Step 4 (Optional) - DEP Enrollment with no account creation SecureToken management

### DEP SecureToken management Reasoning
1. When the user account creation is skipped during a pre-stage enrollment there are situations where the management account can be granted the first SecureToken. Once this secure token is granted it must be used to grant other tokens. 
2. There are other situations after a DEP enrollment or large major OS upgrade that can leave the machine with no SecureTokens. Therefore making grabbing thebe first one for a known administrator account even more important
3. The FV2 authentication screen presents all users that have a SecureToken no matter if they are hidden or not, therefore it is extremely important to try and minimize the number accounts presented to the user at this screen to avoid confusion.

### Implementation
This implementation will take three stages. First, setting up the smart group for the policy. Second, adding the script to JAMF and explaining the script arguments. Third, the actual policy to run our script. Everything followed by some general comments about the script and explanations on why things are done the way they are.

#### Smart Group Scoping Setup
* Name - `Security - SecureToken - Machine Needs remediation`
* Criteria

| And/Or | ( | Criteria | Operator | Value | ) |
|--------|---|-------------------------------|----------------------|----------------------|---|
|  |  | Computer Group | member of | Group containing the computer you would like to target for the endgame |  |
| and |  | SecureToken Status | does not match regex | `[.]*NAME_OF_ADMIN_ACCOUNT[.]*` |  |
| and |  | Computer Group | member of | Group containing all MacOS 10.14+ Machines |  |
| and |  | Assigned User Has SecureToken | is not | `True` |  |   |   |

#### Script Setup
* Name - `enableHiddenAdminForFV2.sh`
* Script - [`enableHiddenAdminForFV2.sh`](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/enableHiddenAdminForFV2.sh)
* Options

    4. Admin Username
    5. Admin Password
    6. Management Account Username
    7. Management Account Password

#### Policy Setup

* General
	* Name - `Maintenance - SecureToken Machine Remediation`
	* Enabled - `True`
	* Triggers
		* Recurring Check-in
	* Frequency - `Ongoing`
* Scripts
	* Script - `enableHiddenAdminForFV2.sh`
	* Priority - `Before`
	* Parameters - Please will all the defined parameters in
* Maintenance
	* Update Inventory - Enabled
* Scope
	* Computer Group - `Security - SecureToken - Machine Needs remediation`

#### General Notes

##### Why is this section of code here?
```shell
# Attempting to remove the secure token from the account
if [[ $(sysadminctl -secureTokenOff $managementUser -password $managementPass -adminUser $adminUser -adminPassword $adminPass 2>&1 | grep -v "Done") ]]; then
        
	# If the removal fails using sysadminctl then nuke the account to get rid of the token
	jamf policy -event recreateManagementAccount
fi
```
There are documented cases I have found where the management account password I had defined can be used to grant a secure token to the admin account, but utilizing that same password to removing the token from the management account will not function. This leaves the only option of removing the SecureToken to be deleting the management account and recreating it. I will put the policy to update the management account in the remaining thoughts section of this readme.

Also why is there not an `!` in front of the `sysadminctl` command in the if statement below?

Well, that's just how the return code for `grep -v` works. ¯\_(ツ)_/¯

## Step 5 - Giving the user a SecureToken

### Implementation
Similar to Step 4 there are going to be multiple steps in getting this thing configured as well

#### Smart Group Scoping Setup
* Name - `Security - SecureToken - Ready for user token assignment`
* Criteria

| And/Or | ( | Criteria | Operator | Value | ) |
|--------|---|-------------------------------|----------------------|----------------------|---|
|  |  | Computer Group | member of | Group containing the computer you would like to target for the endgame |  |
| and |  | SecureToken Status | matches regex | `[.]*NAME_OF_ADMIN_ACCOUNT[.]*` |  |
| and |  | Computer Group | member of | Group containing all MacOS 10.14+ Machines |  |
| and |  | Assigned User Has SecureToken | is | `False` |  |   |   |

#### Script Setup
* Name - `enableHiddenAdminForFV2.sh`
* Script - [`enableUserUsingAdminForFV2.sh`](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/enableUserUsingAdminForFV2.sh)
* Options

    4. Admin Username
    5. Admin Password

#### Policy Setup

* General
	* Name - `Configuration - Enable User account with a Secure Token`
	* Enabled - `True`
	* Triggers
		* Login
	* Frequency - `Ongoing`
	* Client Side Restrictions
		* Limit to Jamf Pro-assigned user - `Enabled`
* Scripts
	* Script - `enableUserUsingAdminForFV2.sh`
	* Priority - `Before`
	* Parameters - Please will all the defined parameters in
* Maintenance
	* Update Inventory - Enabled
* Scope
	* Computer Group - `Security - SecureToken - Ready for user token assignment`

#### General Notes

##### What does the user prompt look like stock?
![alt text](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/User%20Prompt.png "Like this!")

Note - the cancel button is variable which is elaborated upon in the next note, also you can edit the text to be whatever you want

##### What is up with the cancel button and the receipt

In my organization I have a receipt directory in the `/Library/Contoso/Receipts`. Therefore first off, if this directory does not exist then the touch command will fail and you are gonna start getting failures in your Jamf Pro Server reports on the execution of this policy. Also the one time option to cancel will not be a thing. The user will have the ability to cancel as many times as they want. This is not something we wanted, hence I added in the receipt. One Cancel, that's all you get. You can tailor this to do what you want.

## Step 6 - Enabling FileVault

### Implementation
This last one is thankfully a little easier! Now that we have our user with a SecureToken we can look at enabling FileVault 2. The general setup for this is below. Feel free to customize it using your own secret sauce.

#### Smart Group Scoping Setup
* Name - `Security - SecureToken - Assigned User has Token`
* Criteria

| And/Or | ( | Criteria | Operator | Value | ) |
|--------|---|-------------------------------|----------------------|----------------------|---|
|   |   | Assigned User Has SecureToken | is | `True` |  |   |   |

Note - The smart group criteria is VERY flexible and probably needs more client disk state validation as defined in [Jamf FV2 Technical documentation](https://docs.jamf.com/technical-papers/jamf-pro/administering-filevault-macos/10.7.1/Creating_Smart_Computer_Groups_for_FileVault.html#src-19532040_id-.CreatingSmartComputerGroupsforFileVault1v2018-CreatingaSmartGroupforFileVaultEligibleComputersthatareNotYetEncrypted)

#### Policy Setup

* General
	* Name - `Configuration - Enable FileVault 2 Configuration on Next login`
	* Enabled - `True`
	* Triggers
		* Recurring Check-in
	* Frequency - `Once per Computer`
* Disk Encryption
	* Action - `Apple Disk Encryption Configuration`
	* Disk Encryption Configuration - Contoso Disk Encryption Configuration (You'll need to make this under the [Disk Encryption Settings](https://docs.jamf.com/10.12.0/jamf-pro/administrator-guide/Managing_Disk_Encryption_Configurations.html))
	* Require FileVault 2 - `At Next Login` (my personal preference)
* Scope
	* Computer Group - `Security - SecureToken - Assigned User has Token`
* User Interaction
	* Complete Message - `FileVault 2 has been enabled. Please restart to begin`
	
#### General Notes

This policy and what it actually is both scoped to and what it really does is extremely environment dependent. I can only advise what I am intending for my own environment. Your mileage always will vary.

# Remaining Thoughts

### Nuking and Re-Creating the management account

The policy I have is as follows, please use this as a template.

* General
	* Name - `Utility - Remove and re-create management account`
	* Enabled - `True`
	* Triggers
		* Custom
			* `recreateManagementAccount`
	* Frequency - `Ongoing`
* Scripts 
	* Script - `DeleteManagmentAccount.sh`
		* Script contents are as follows
		```
		#!/bin/bash
		sysadminctl -deleteUser MANAGEMENT_ACCOUNT_USERNAME -secure
		```
	* Priority - `Before`
* Local Accounts
	* Create New Account - `Selected`
	* Username - You management account username
	* Password & Verify Password - You management account password
	* Home Directory Location - `/private/var/MANAGEMENT_ACCOUNT_USERNAME`
	* Allows the user to administer computer - `Enabled`
* Scope
	* All Computers

### Changing the admin password

Have not had to deal with this personally yet, but to accomplish this it would be a combination of both using the `passwd` binary to change the password on the MacOS side, but then also a `diskutil apfs changePassphrase BOOTDISK -user UUID` to get the FileVault side changed as well. Also you will need to update all your script parameters

### Login trigger firing issues

I have noticed some issues where the second login trigger will fail to launch in a timely manner after the second login due to Jamf's `-randomDelay` parameter being called by another login trigger. Therefore the creation of a script that is called by [outset](https://github.com/chilcote/outset) under the `login-every-privileged` config that calls the `login` Jamf policy trigger and nuking any process waiting with a `-randomDelay` would be the way to remediate this. I might write this script if I notice this issue more prevalent in my own environment

### Do I work for Contoso Corp?
No, It's a filler name. Put your own company names here

### Why do I NOT want to use this in a Lab situation

The FV2 authentication screen only respects the accounts that have a SecureToken enabled on them on that local machine. In Lab situations whether you are binding you machines to LDAP/AD or using something like NoLo/Jamf Connect the FV2 authentication screen happnens before those products even start. Therefore upon a reboot/cold boot a brand new user to that machine will have no method of logging in. Hence, why you don't want to use FV2 in Lab situations

### I'm worried about passing passwords in plain text

This [method of encrypting those parameters](https://github.com/jamf/Encrypted-Script-Parameters) is the best I am going to be able to do. If that does not work for you, then this workflow might not be for you.

### I want more information on SecureTokens creation issues

Check this out: https://travellingtechguy.eu/final-wrap-up-on-secure-tokens/

Also there is Apple's documentation: https://help.apple.com/deployment/macos/?lang=en#/apd8faa99948

## License

[WTFPL](http://www.wtfpl.net/)
