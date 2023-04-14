#!/bin/bash

# Author:      Jonathan Bateman
# Version:     1.0
# Description: Script to automate various administration jobs
#

readonly USER=$(id -un)
readonly DATE=$(date +%d/%m/%Y)
readonly LOG_DIR='/tmp/log/'
readonly SSH_OPTIONS='-o ConnectTimeout=2'
readonly USER_LIST="/etc/passwd"
readonly USER_STATUS_LIST="/etc/shadow"
readonly MOUNT_ROOT="/media/"

HOST="$(hostname)"
LENGTH=8

# Display correct usage of script to user.
usage() {
  echo "Usage: ${0} [-l] [-p LENGTH]" >&2
  echo "  -l         Log all commands executed to a file, /tmp/log/unix-admin-zsh-<date>.log" >&2
  echo "  -p LENGTH  Specify length for randomly generated passwords." >&2
  echo "  -s         Run commands using root privileges" >&2
  exit 1
}

# Main menu screen, show options to the user.
menuscreen() {
  echo "-----------------------------------------------------------------------------------------------"
  echo "User: ${USER}    Host: ${HOST}    Date: ${DATE}"
  echo "-----------------------------------------------------------------------------------------------"
  echo "         1  : Set Remote Host"
  echo "         2  : Display users"
  echo "         3  : Add a new User"
  echo "         4  : Delete a user"
  echo "         5  : Disable User"
  echo "         6  : Enable User"
  echo "         7  : Change password for user"
  echo "         8  : Mount local Drive"
  echo "         9  : Unmount local Drive"
  echo "         10 : Mount Network Share Drive"
  echo "         q  : Quit"
  echo "-----------------------------------------------------------------------------------------------"
}

# If the 'l' option is supplied create a log file for loggig all commands executed.
create_log_file() {
  if [[ ! -d "${LOG_DIR}" ]]
  then
    mkdir -p "${LOG_DIR}"

    if [[ "${?}" -gt 0 ]]
    then
      # Could not create log directory, exit the script.
      echo "Unable to create log directory ${LOG_DIR}, permission denied."
      exit 1
    fi
  fi

  # Create log file in appropriate directory
  LOG_FILE="${LOG_DIR}unix-admin-zsh-$(date +%Y%m%d%H%M%S).log"
  echo "Host: ${HOST}  User: ${USER}" > "${LOG_FILE}"

  if [[ ! -e "${LOG_FILE}" ]]
  then
    # Could not create log file, exit script.
    echo "Could not create log file."
    exit 1
  fi    
}

# Display user messages and write to log file if appropriate.
log() {
  if [[ "${LOG}" = 'true' ]]
  then
    echo "${@}" | tee "${LOG_FILE}"
  else
    echo "${@}"
  fi
}

# Take user input to set the remote host.
remote_host() {
  log "HOST:${HOST}    COMMAND: Set Remote Host"
  echo "Enter remote host name: "
  read HOST

  # Make sure we can connect to the supplied host.
  local LOG_STDOUT=$(ping -c 1 ${HOST})
  local RESULT="${?}"
  log "${LOG_STDOUT}"

  if [[ "${RESULT}" -gt 0 ]]
  then
    log "Ping failed, unable to set remote host."
    HOST="$(hostname)"
  else
    log "Remote Host: ${HOST}"
    SSH_CONN="ssh ${SSH_OPTIONS} ${HOST}"
  fi
}

# Display list of users with UID >= 1000, UID of 0 - 999 typically reserved for system users.
display_users() {
  log "HOST:${HOST}    COMMAND: Display Users"
  local STATUS

  # Check we can access the shadow file.
  ${SSH_CONN} ${SUDO} test -r ${USER_STATUS_LIST}
  if [[ "${?}" -gt 0 ]]
  then
    log "Permission denied: ${USER_STATUS_LIST} is not accessible"
    return
  fi

  log "USER:UID:COMMENT:LOCKED"
  
  ${SSH_CONN} ${SUDO} cat /etc/passwd | awk -F ':' '{print $1 " " $3 " " $5}' | while read ACCOUNT ID COMMENT
  do
    if [[ "${ID}" -gt 999 ]]
    then
      # Determine locked status of account.
      if [[ $(${SSH_CONN} ${SUDO} grep ${ACCOUNT} ${USER_STATUS_LIST} | awk -F ':' '{print $2}' | cut -b 1) = "!" ]]
      then
        STATUS="Locked"
      else
        STATUS=''
      fi

      log "${ACCOUNT}:${ID}:${COMMENT}:${STATUS}"
    fi
  done
}

# Create a new user, password will be randomly generated and then immediately expired. This
# will force user to change password on first login. User will be prompted if they want to
# generate a home directory for the new user. Adding a comment for the new user is optional
add_user() {
  log "HOST:${HOST}    COMMAND: Add User"

  # Check we have sufficient privileges to add a new user.
  if [[ "${HOST}" = $(hostname) ]] && [[ "${SUDO}" != 'sudo' ]]
  then
    log "Insufficient privileges, permission denied"
    return
  fi

  echo "Username:"
  local USERNAME
  read USERNAME
  echo "Comment:"
  local COMMENT
  read COMMENT

  # Generate a password of set length.
  local SPECIAL_CHARACTER=$(echo '!@#$%^&*()_-+=' | fold -w1 | shuf | head -c1)
  local PASSWORD=$(date +%s%N${SPECIAL_CHARACTER} | sha256sum | head -c${LENGTH})

  # Add the new user.
  ${SSH_CONN} ${SUDO} useradd -c "${COMMENT}" -m ${USERNAME} &> /dev/null

  if [[ "${?}" -ne 0 ]]
  then
    log "Could not create user ${USERNAME}!"
    return
  fi

  # Assign password to user.
  ${SSH_CONN} echo "${USERNAME}:${PASSWORD}" | ${SUDO} chpasswd &> /dev/null

  if [[ "${?}" -eq 0 ]]
  then
    # Expire the password.
    ${SSH_CONN} ${SUDO} passwd -e ${USERNAME} &> /dev/null
    log "USER:${USERNAME} created    PASSWORD:${PASSWORD}"
  else
    log "Error: Could not assign password to ${USERNAME}"
  fi
}

# Forcibly delete a user. Any processes associated with the user will be terminated.
# Users's home directory will be removed along with any files it contains.
delete_user() {
  log "HOST:${HOST}    COMMAND: Delete User"

  # Check we have sufficient privileges to delete a user.
  if [[ "${HOST}" = $(hostname) ]] && [[ "${SUDO}" != 'sudo' ]]
  then
    log "Insufficient privileges, permission denied"
    return
  fi

  echo "Username:"
  local USERNAME
  read USERNAME

  # Delete the user.
  ${SSH_CONN} ${SUDO} userdel -rf ${USERNAME} &> /dev/null

  if [[ "${?}" -ne 0 ]]
  then
    log "Could not delete user ${username}!"
  else
    log "USER:${USERNAME} deleted."
  fi
}

# Disable or lock user account, requires root privileges.
change_user_state() {
  local STATE

  # Check we have sufficient privileges to add a new user.
  if [[ "${HOST}" = $(hostname) ]] && [[ "${SUDO}" != 'sudo' ]]
  then
    log "Insufficient privileges, permission denied"
    return
  fi

  if [[ "${1}" = "-L" ]]
  then
    STATE="disable"
  else
    STATE="enable"
  fi

  log "HOST:${HOST}    COMMAND: ${STATE^} User"

  echo "Username:"
  local USERNAME
  read USERNAME

  # Enable/disable the user.
  ${SSH_CONN} ${SUDO} usermod ${1} ${USERNAME} &> /dev/null

  if [[ "${?}" -ne 0 ]]
  then
    log "Could not ${STATE} user ${username}!"
  else
    log "USER:${USERNAME} ${STATE}d."
  fi
}

# Display a list of attached storage devices.
list_drives() {
  # Display list of attached storage devices.
  echo "NAME SIZE TYPE MOUNTPOINTS"
  ${SSH_CONN} lsblk -l | grep '^sd' | grep -e 'disk' -e 'part' | awk '{print $1 " " $4 " " $6 " " $7}'
}

# Mount a storage device. Requires root privileges
mount_local_drive() {
  log "HOST:${HOST}    COMMAND: Mount Local Drive"

  # Check we have sufficient privileges to add a new user.
  if [[ "${HOST}" = $(hostname) ]] && [[ "${SUDO}" != 'sudo' ]]
  then
    log "Insufficient privileges, permission denied"
    return
  fi

  echo "Select drive (enter to return to menu):"
  local DRIVE
  read DRIVE

  if [[ ! -n "${DRIVE}" ]]
  then
    return
  fi

  echo "Enter MountPoint directory name:"
  local MOUNTPOINT
  read MOUNTPOINT

  # Create the mount point directory.
  ${SSH_CONN} ${SUDO} mkdir ${MOUNT_ROOT}${MOUNTPOINT}

  # Mount the drive
  ${SSH_CONN} ${SUDO} mount /dev/${DRIVE} ${MOUNT_ROOT}${MOUNTPOINT} &> /dev/null

  if [[ "${?}" -ne 0 ]]
  then
    log "Could not mount ${DRIVE}!"
  else
    log "Drive ${DRIVE} mounted. MountPoint: ${MOUNT_ROOT}${MOUNTPOINT}"
  fi
}

# Unmount a storage device. Requires root privileges.
unmount_local_drive() {
  log "HOST:${HOST}    COMMAND: Unmount Local Drive"

  # Check we have sufficient privileges to add a new user.
  if [[ "${HOST}" = $(hostname) ]] && [[ "${SUDO}" != 'sudo' ]]
  then
    log "Insufficient privileges, permission denied"
    return
  fi

  echo "Select drive (enter to return to menu):"
  local DRIVE
  read DRIVE

  if [[ ! -n "${DRIVE}" ]]
  then
    return
  fi

  # Get the mount point directory.
  local MOUNTPOINT=$(lsblk -l | grep "${DRIVE}" | awk '{print $7}')

  # Unmount the drive.
  ${SSH_CONN} ${SUDO} umount ${MOUNTPOINT} &> /dev/null

  if [[ "${?}" -ne 0 ]]
  then
    log "Could not unmount ${DRIVE}!"
    return
  else
    log "Drive ${DRIVE} unmounted."
  fi

  # Remove the mount point directory
  ${SSH_CONN} ${SUDO} rm -r ${MOUNTPOINT}
}

mount_network_drive() {
  log "HOST:${HOST}    COMMAND: Mount Shared Network Drive"

  # Check we have sufficient privileges to mount shared network storage.
  if [[ "${SUDO}" != 'sudo' ]]
  then
    log "Insufficient privileges, permission denied"
    return
  fi

  # Retrieve start of ip address range.
  local IP_RANGE_START=$(${SSH_CONN} route -n | grep 'U[ \t]' | awk '{print $1}') # returns 192.168.0.0

  # Display local network device names with associated ip addresses.
  ${SSH_CONN} ${SUDO} nmap -sP ${IP_RANGE_START} | grep -v "Starting" | grep -v "done" | \ 
  grep -e "Nmap" -e "MAC" | cut -d '(' -f2 | cut -d ')' -f1 | awk '/ for / {print $5} !/ for / {print $1}'
  
  # Mount the network drive.
  ${SSH_CONN} ${SUDO} mount -t cifs -o user=${USERNAME} //${IP_ADDRESS}/Jon /media/share/diskstation
}

# Script starting point.

# Process the script options.
clear
while getopts lp:s OPTION
do
  case ${OPTION} in
    l)
      LOG='true'
      create_log_file
      ;;
    p)
      LENGTH="${OPTARG}"
      ;;
    s)
      SUDO="sudo"
      echo "Running script with ROOT privileges!" >&2
      ;;
    ?)
      usage
      ;;
  esac
done

while :
do
  menuscreen
  echo "Choose option: "
  read CHOICE
  clear
  case ${CHOICE} in
    1)
      remote_host
      ;;
    2)
      display_users
      ;;
    3)
      add_user
      ;;
    4)
      delete_user
      ;;
    5)
      change_user_state -L
      ;;
    6)
      change_user_state -U
      ;;
    7)
      ;;
    8)
      list_drives
      mount_local_drive
      ;;
    9)
      list_drives
      unmount_local_drive
      ;;
    10)
      mount_network_drive
      ;;
    q)
      exit 0
      ;;
    ?)
      echo "Unknown user response."
      ;;
  esac
done
