#!/bin/bash
#
# Author: Johan McGwire - Yohan @ Macadmins Slack - Johan@McGwire.tech
#
# Description: This Jamf Extension Attribute reports the current SecureToken list

# Outputting the SecureToken list in the proper result tags
echo "<result>$(fdesetup list)</result>"

# Exiting with zero becuase it is an EA and we don't really care
exit 0