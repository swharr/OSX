#!/bin/sh
#
# changeShortName
#
# Author: Shon W. Harris (shon.harris@eccles.utah.edu)
#
# This Script will change the User's Unix Account Name (Short Name) to their University of Utah Network ID (uNID)
#
# Useage:
#
#	changeShortName [ -o old_sn ] [ -n new_sn ]
#
#	This script must be executed with administrative privileges
#
#	To change a user's shortname interactively, launch this script without arguments
#
#		Example:
#
#			changeShortName
#
#	Alternately, specify the old and new names that you'd like to change
#
#	Example:
#
#			changeShortName -o Smith Kennedy -n u01234567
#
# =====================================================================================================================================|
# LICENSE
# This script is provided at will and with no warranty, written, or implied. You are using this script at your own risk. Proceed with  |
# Extreme caution.
# This script must be run with root user privledges, or at least sudo privledges. It works better however if you use root. 			   |
# =====================================================================================================================================|

#Lets go. Fire the Script.
OLD_SN="NULL"
NEW_SN="NULL"
SWVERS="`defaults read /System/Library/CoreServices/SystemVersion ProductVersion`"

get_old_sn(){
# query user for short name to change
echo "Please enter the Current short name of the user that you would like to change:"
read OLD_SN
echo "You have entered: $OLD_SN.  Is this correct? (y/n)"
read VERIFY_NAME
case $VERIFY_NAME
	in
		y|Y)
			continue;;
		n|N)
			get_old_sn
			continue;;
		*)
			echo "Error: Unrecognized option - enter \"y\" or \"n\""
			get_old_sn
			continue;;
esac
}

get_new_sn(){
# prompt the user to enter new shortname in uNID format.
echo "Please enter the new shortname (u01234567) for user: $OLD_SN"
read NEW_SN
echo "You have entered: $NEW_SN - is this correct? (y/n)"
read VERIFY_NEW_SN
case $VERIFY_NEW_SN
	in
		y|Y)
			continue;;
		n|N)
			get_new_sn
			continue;;
		*)
			echo "Unrecognized option - enter \"y\" or \"n\""
			get_old_sn
			continue;;
esac
}

check_root() {
    if [ `whoami` != "root" ]
    then
        echo "FORBIDDEN. Insufficient permissions: this script MUST be executed as root"
		exit 0;
    fi
}

check_new_sn_exists(){
	VERIFY_NEW_USER_EXISTS=`dscl . -read /users/"$OLD_SN" name | sed -e s/.*name..//`

	if [ "$NEW_SN" = "$VERIFY_NEW_USER_EXISTS" ]; then
		echo "Error: user: $NEW_SN already exists."
		exit 0;
	fi
}

main(){
	# Are we sure that the user we are renaming actually exists? No? Thats why we are checking here.
	if [ "$VERBOSE" = "YES" ]; then
		echo "Verifying existance of user: $OLD_SN..."
	fi

	VERIFY_USER_EXISTS=`dscl . -read /users/"$OLD_SN" name | sed -e s/.*name..//`

	if [ "$OLD_SN" = "$VERIFY_USER_EXISTS" ]; then
		if [ "$VERBOSE" = "YES" ]; then
			echo "User: $VERIFY_USER_EXISTS exists - continuing..."
		fi

		# if the script was launched without a new short name, we probably should ask for one here.
		if [ "$NEW_SN" = "NULL" ]; then
			get_new_sn
		fi
		check_new_sn_exists

		# change all values in this user's directory entry that match old sn to the new uNID format.
		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing _writers_passd for user $OLD_SN"
		fi
		dscl . -delete /users/$OLD_SN _writers_passwd
		dscl . -create /users/$OLD_SN _writers_passwd $NEW_SN

		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing _writers_hint for user $OLD_SN"
		fi
		dscl . -delete /users/$OLD_SN _writers_hint
		dscl . -create /users/$OLD_SN _writers_hint $NEW_SN

		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing _writers_picture for user $OLD_SN"
		fi
		dscl . -delete /users/$OLD_SN _writers_picture
		dscl . -create /users/$OLD_SN _writers_picture $NEW_SN

		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing _writers_password for user $OLD_SN"
		fi
		dscl . -delete /users/$OLD_SN _writers_tim_password
		dscl . -create /users/$OLD_SN _writers_tim_password $NEW_SN

		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing _writers_realname for user $OLD_SN"
		fi
		dscl . -delete /users/$OLD_SN _writers_realname
		dscl . -create /users/$OLD_SN _writers_realname $NEW_SN

		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing home for user $OLD_SN"
		fi
		dscl . -delete /users/$OLD_SN home
		dscl . -create /users/$OLD_SN home /Users/$NEW_SN

		if [ "$VERBOSE" = "YES" ]; then
			echo "Changing name of user $OLD_SN to $NEW_SN"
		fi
		dscl . -create /users/$OLD_SN name $NEW_SN

		# determine if the user's sn has been used for any groups, and if so, change it to the new sn (10.4 only)
		case $SWVERS
			in
				10.5*)
					GROUP=`dscl . -search /groups name $OLD_SN | sed s/dsAttrTypeNative:name....// | sed s/\)// | sed s/\ .*// |  grep [^*] > /tmp/changeShortName.$$.group_name`
					continue;;
				10.4*)
					GROUP=`dscl . -search /groups name $OLD_SN | sed s/name*.*// > /tmp/changeShortName.$$.group_name`
					continue;;
		esac
		# if the user's short name HAS been used as a group (other than admin), remove the group, and readd it using the new name.
		if [ -f  "/tmp/changeShortName.$$.group_name" ]; then
			cat "/tmp/changeShortName.$$.group_name" |
			while read GROUP
			do
				# Lets make certain we have not renamed the admin group.
				if [ "$GROUP" != "admin" ]; then
					if [ "$VERBOSE" = "YES" ]; then
						echo "Renaming $GROUP group to $NEW_SN"
					fi
					dscl . -create /groups/$GROUP name $NEW_SN
				fi
			done
			rm "/tmp/changeShortName.$$.group_name"
		fi

		# determine the groups that the user is a part of and change each entry to the new short name in uNID format.
		case $SWVERS
			in
				10.5*)
					GROUP_MEMBERSHIP=`dscl . -search /groups users $OLD_SN | sed s/dsAttrTypeNative:users....// | sed s/\)// | sed s/\,// | sed s/\ .*// |  grep [^*] > /tmp/changeShortName.$$.groups`
					continue;;
				10.4*)
					GROUP_MEMBERSHIP=`dscl . -search /groups users $OLD_SN | sed s/users.*// > /tmp/changeShortName.$$.groups`
					continue;;
		esac

		# if the old short name is in 1 or more groups, remove them, and add the new shortname in uNID format.
		if [ -f  "/tmp/changeShortName.$$.groups" ]; then
			cat "/tmp/changeShortName.$$.groups" |
			while read GROUP_MEMBERSHIP
			do
				if [ "$VERBOSE" = "YES" ]; then
					echo "Removing $OLD_SN from group $GROUP_MEMBERSHIP"
				fi
				ERROR=`dscl . -delete /groups/$GROUP_MEMBERSHIP users $OLD_SN`
				if [ "$VERBOSE" = "YES" ]; then
					echo "Adding $NEW_SN to group $GROUP_MEMBERSHIP"
				fi
				dscl . -append /groups/$GROUP_MEMBERSHIP users $NEW_SN
			done
			rm "/tmp/changeShortName.$$.groups"
		fi

		# move home directory to new uNID shortname value
		if [ -d "/Users/$OLD_SN" ]; then
			cd /Users
			mv "$OLD_SN" "$NEW_SN"
		fi
	else
		echo "Error: user: $OLD_SN not found."
	fi
}

# We need to make sure that root is running this command, so check it here.
check_root

# Make sure we parse the command line arguments, or define them.
while getopts o:n:v SWITCH
do
        case $SWITCH in
                o) OLD_SN=$OPTARG;;
                n) NEW_SN=$OPTARG;;
                v) VERBOSE=YES;;
                *)  echo "changeShortName script for Mac OS X"
                    echo useage: changeShortName [ -o old_short_name] [ -n new_short_name] [-v]
                    echo "-o defines the old short name of the user that you would like to change"
                    echo "-n defines the new short name. Must be in a true uNID format."
                    echo "use -v for verbose logging"
					echo ""
                    echo example:
                    echo "Change a user's short name: changeShortName -o Smith Kennedy -n u01234567 -v"
                    echo ""
					echo "Root (either via Sudo or Root) privileges are required to run this script"
                    exit 1;;
        esac
done

# If we launch the script without any valid arguments, ask for them here.
if [ "$OLD_SN" = "NULL" ]; then
	get_old_sn
fi

# run main script function
main