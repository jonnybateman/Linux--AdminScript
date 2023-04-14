# Linux--AdminScript

A shell script for Linux distributions that automates a number of administration tasks. Commands executed by the script can also be applied to a different host/virtual machine from the one currently logged in to.

## Script Options

* -l: Log all commands executed by script to a log file (/tmp/log/unix-admin-`shell`-`date`.log).
* -p LENGTH: Specify length for randomly generated passwords when performing user admin tasks.
* -s: Run commands using root privileges. Will be prompted for password. Current user must be one with root privileges.

## Admin Tasks

|Method|Root Privileges|Description|
|------|:-------------:|-----------|
|Set Remote Host|No|Set the remote host where the admin tasks are to be performed. Host will be pinged and if successful a SSH connection will be made.|
|Display List of Users|Yes|Display a list of non-system users n the current host.|
|Add a New User|Yes|Create a new user. Will be prompted for a username and comment. A randomly generated password will be assigned to the new user which will be expired forcing the user to change it on forst log in. Default password size is 8 characters. This default can be changed using the -p option.|
|Delete a User|Yes|Delete a user account. Will prompted to enter username for deletion. Home directory of the user will also be removed.|
|Disable User|Yes|Disable the targeted user. Will be prompted to enter the username to be disabled.|
|Enable User|Yes|Enable the targeted user. Will be prompted to enter the username to be enabled.|
|Change Password for User|Yes|Changes the password for the targeted user to a randomly generated one. New password will be set to expired to force the user to change it on first log in.|
|List Attached Storage Devices|No|Will list the attached storage devices of type `disk` or `partition`. Information displayed:<ul><li>Name</li><li>Size</li><li>Type</li><li>Mountpoint</li>|
