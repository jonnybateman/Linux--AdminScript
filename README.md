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
