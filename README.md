# Automatic-Secure-Token-Granting-Workflow
This workflows allows for the automatic granting of secure tokens to the Jamf Pro Assigned user on a machine utilizing a known SecureToken Enabled administrator account

## Endgame
To have a user driven, automatic method of enabling the primary user on a machine with a SecureToken and have FileVault enabled with a method of enabling future accounts

## Reasoning
With the Apple implementation of giving SecureTokens to accounts that do not have them, it requires the user to enter the credentials to the SecureToken enabled administrator account. This is obviously something that a system administrator would not want a user to know or do. Therefore we need a way of placing the SecureToken enviornment into a known state with the 

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
Due to the limitation of not being able to do any funky regex on the Jamf pro side to check if the assigned user has a token. Therefore we need an EA. This EA uses an API call with Jamf to get the assigned user username, then checks that against the SecureToken enabled users on the machine. We can’t use script parameters to get the API username and password unfortunately because it is an EA. The contents of the EA are below

* Name - `Assigned User has SecureToken	`
* Data Type - `String`
* Input Type - `Script`
* Script - [`assignedUserFV2EnabledEA.sh`](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/assignedUserFV2EnabledEA.sh)

Note: You will need to add your Jamf Pro Server API username and password to the script for it to function

## Step 4 (Optional) - DEP Enrollment with no account creation SecureToken management

### DEP SecureToken management Reasoning
1. When the user account creation is skipped during a pre-stage enrollment there are situations where the management account can be granted the first SecureToken. Once this secure token is granted it must be used to grant other tokens. 
2. There are other situations after a DEP enrollment or large major OS upgrade that can leave the machine with no SecureTokens. Therefore making grabbing theb first one for a known administrator account even more important
3. The FV2 authentiation sceen presents all users that have a SecureToken no matter if they are hidden or not, therefore it is extremely important to try and minimize the number accounts presented to the user at this screen to avoid confusion.

### Implementation
This implementation will take three stages. First, setting up the smart group for the policy. Second, adding the script to JAMF and explaining the script agruments. Third, the actual policy to run our script. Everything followed by some general comments about the script and explanations on why things are done the way they are.

#### Smart Group Scoping Setup
* Name - `Security - SecureToken - PRI Needs remediation`
* Criteria

| And/Or | ( | Criteria | Operator | Value | ) |
|--------|---|-------------------------------|----------------------|----------------------|---|
|  |  | Computer Group | member of | Group containing the computer you would like to target for the endgame |  |
| and |  | SecureToken Status | does not match regex | `[.]*NAME_OF_ADMIN_ACCOUNT[.]*` |  |
| and |  | Computer Group | member of | Group containing all MacOS 10.14+ Machines |  |
| and |  | Assigned User Has SecureToken | is not | `True` |  |   |   |

#### Script Setup
* Name - `enableHiddenAdminForFV2.sh`
* Script - [`enableUserUsingAdminForFV2.sh`](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/enableUserUsingAdminForFV2.sh)
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

#### General Notes

##### Why is this section of code here?
```shell
# Attempting to remove the secure token from the account
if [[ $(sysadminctl -secureTokenOff $managementUser -password $managementPass -adminUser $adminUser -adminPassword $adminPass 2>&1 | grep -v "Done") ]]; then
        
	# If the removal fails using sysadminctl then nuke the account to get rid of the token
	jamf policy -event recreateManagementAccount
fi
```
There are documented cases I have found where the management account password I had defined can be used to grant a secure token to the admin account, but utilizing that same password to removing the token from the management account will not function. This leaves the only option of removing the account to be deleting the management account and recreating it. I will put the policy to update the management account in the remaining thoughts section of this readme.

Also why is there not an `!` in front of the `sysadminctl` commmand in the if statement below?

Well, that's just how the return code for `grep -v` works. ¯\_(ツ)_/¯

## Step 5 - Giving the user a SecureToken
Step 2 is enabling you user to get a token at login. This can be done utilizing the script titled `enableUserUsingAdminForFV2.sh`, It takes in your admin username and password as Jamf script parameters and uses those to enable the account with a token. That being said we don’t want just any user to get a token, we want the assigned user to have a token. Therefore in the policy we set the following things:
```
General:
	Trigger: Login 
	Frequency: Ongoing
	Client Side Restriction: Limit to Jamf Pro-assigned user

Maintenance:
	Update Inventory: Enabled
```
## Step 6 - Enabling FileVault

# Remaining Thoughts

### Changing the admin password

### Login trigger firing issues
