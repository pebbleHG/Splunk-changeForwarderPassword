# Splunk-changeForwarderPassword
App to change password on forwarders managed by deployment server

Use case: customer has multiple versions of Splunk Universal Forwarder in their environment; some have known passwords, and some don't.  They would like to consolidate to one password for all of them that is non-default.

Issues: UF versions range from 6.5 to 7.2.5.1; that means different methods are required to change password, depending on version
< 7.1.0 forwarders allow password change via splunk CLI
>= 7.1.0 forwarders require use of user-seed.conf

Solution:
1. Deploy scripted input via deployment server
2. If version < 7.1.0:
   remove the existing $SPLUNK_HOME/etc/passwd and restart in order to reset credentials to admin/changeme
   run splunk command to change password
   
   If version >= 7.1.0:
   remove the existing $SPLUNK_HOME/etc/passwd
   generate $SPLUNK_HOME/etc/system/local/user-seed.conf
   restart forwarder in order read configuration from user-seed.conf and then delete it
   
