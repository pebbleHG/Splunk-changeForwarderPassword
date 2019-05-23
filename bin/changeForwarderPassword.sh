#!/bin/bash
# Define the original and new passwords here. To have a password automatically generated, set NEWPASS to 'auto'
OLDPASS=changeme
NEWPASS=auto

# Fork logic depending on Splunk version
#   if < 7.1.0, use splunk cmd to change password
#   if >= 7.1.0, use user-seed.conf

SPLUNK_HOME=/opt/splunk

SPLUNK_VERSION=`/opt/splunk/bin/splunk version |sed -r 's/\w+\s([0-9]\.[0-9]).*/\1/'`
VERSION_THRESHOLD=7.1

# using bc since I'm doing binary comparison
COMPARE_THRESHOLD=`echo "$SPLUNK_VERSION < $VERSION_THRESHOLD" | bc`

   # Look for the checkpoint file and error out if it exists
   if [ -f $SPLUNK_HOME/etc/pwd_changed ]
   then
        echo `date -R` $HOSTNAME: Splunk account password was already changed.
        exit
   fi

# if the version is less than 7.1, use OG password changing convention
if [$COMPARE_THRESHOLD = '1' ]

   if [ "$NEWPASS" = "auto" ]
   then
	NEWPASS=`head -c 500 /dev/urandom | sha256sum | base64 | head -c 16 ; echo`
	NEWPASSAUTO=`echo Automatic password: $NEWPASS`
   fi

   # remove $SPLUNK_HOME/etc/passwd and restart Splunk Forwarder in order to reset admin password to changeme
   rm $SPLUNK_HOME/etc/passwd
   echo "restarting Splunk Forwarder"
   $SPLUNK_HOME/bin/splunk restart &
   wait || { echo "there were errors" >&2; exit 1; }
   echo "restart attempt completed"

   # Change the password
   $SPLUNK_HOME/bin/splunk edit user admin -password $NEWPASS -auth admin:$OLDPASS > /dev/null 2>&1

   # Check splunkd.log for any error messages relating to login during the script and determine whether the change was successful or not
   CHANGED=`tail -n 100 $SPLUNK_HOME/var/log/splunk/splunkd.log | grep pwchange | grep Login`
   if [ -z "$CHANGED" ]
   then
	echo `date -R` $HOSTNAME: Splunk account password successfully changed. $NEWPASSAUTO
	echo `date -R` $HOSTNAME: Splunk account password successfully changed. > $SPLUNK_HOME/etc/pwd_changed
   else
	echo `date -R` $HOSTNAME: Splunk account login failed. Old password is not correct for this host.
   fi
else
USER_SEED=$SPLUNK_HOME/etc/system/local/user-seed.conf

# remove $SPLUNK_HOME/etc/passwd and generate user-seed.conf
   if [ -f $USER_SEED ]
   then
      echo `date -R` $HOSTNAME: $USER_SEED already exists; stopping
      exit
   fi
   rm $SPLUNK_HOME/etc/passwd
   
   # generate user-seed.conf
   cat << EOF >> $USER_SEED
   [user-info]
   USERNAME = admin
   PASSWORD = $NEWPASS
   EOF
   
   # restart splunk to read in user-seed.conf
   echo "removed password and created user-seed, now restarting Splunk Forwarder"
   $SPLUNK_HOME/bin/splunk restart &
   wait || { echo "there were errors" >&2; exit 1; }
   echo "restart attempt completed"

   # Check splunkd.log for any error messages relating to login during the script and determine whether the change was successful or not
   CHANGED=`tail -n 100 $SPLUNK_HOME/var/log/splunk/splunkd.log | grep pwchange | grep Login`
   if [ -z "$CHANGED" ]
   then
	echo `date -R` $HOSTNAME: Splunk account password successfully changed. $NEWPASSAUTO
	echo `date -R` $HOSTNAME: Splunk account password successfully changed. > $SPLUNK_HOME/etc/pwd_changed
   else
	echo `date -R` $HOSTNAME: Splunk account login failed. Old password is not correct for this host.
   fi
fi
