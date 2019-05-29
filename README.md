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
```
Name: SecureToken Status
Data Type: String
Input Type: Script
Script: See below
```
For the script enter the contents of the [SecureTokenStatusEA.sh](https://github.com/Yohan460/Automatic-Secure-Token-Granting-Workflow/blob/master/SecureTokenStatusEA.sh)

## Step 3 (Optional) - DEP Enrollment with no account creation SecureToken management

### DEP SecureToken management Reasoning
1. When the user account creation is skipped during a pre-stage enrollment there are situations where the management account can be granted the first SecureToken. Once this secure token is granted it must be used to grant other tokens. 
2. There are other situations after a DEP enrollment or large major OS upgrade that can leave the machine with no SecureTokens. Therefore making grabbing theb first one for a known administrator account even more important
3. The FV2 authentiation sceen presents all users that have a SecureToken no matter if they are hidden or not, therefore it is extremely important to try and minimize the number accounts presented to the user at this screen to avoid confusion.

### Implementation
This implementation will take two

#### Smart Group Scoping


## Step 4 - Giving the user a SecureToken
Step 2 is enabling you user to get a token at login. This can be done utilizing the script titled `enableUserUsingAdminForFV2.sh`, It takes in your admin username and password as Jamf script parameters and uses those to enable the account with a token. That being said we don’t want just any user to get a token, we want the assigned user to have a token. Therefore in the policy we set the following things:
```
General:
	Trigger: Login 
	Frequency: Ongoing
	Client Side Restriction: Limit to Jamf Pro-assigned user

Maintenance:
	Update Inventory: Enabled
```
	
## Step 5 - Reporting on the Assigned User SecureToken Status
This ensures the assigned user has a token. That being said we can’t scope on a policy already having run and can’t do any funky regex on the Jamf pro side to check if the assigned user has a token. Therefore we need an EA. This can be done using the script below titled `assignedUserFV2EnabledEA.sh`. This uses an API call with Jamf to check if the assigned user has a secure token. Can’t use script parameters to get the API username and password unfortunately because it is an EA. Once that EA reports `True` you are in the clear to scope out your FV2 enablement policy of your own choice.

# Remaining Thoughts

### Changing the admin password

### Login trigger firing issues
