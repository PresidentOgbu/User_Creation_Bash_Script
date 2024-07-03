#!/bin/bash

# Define file paths
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Create log and password files with proper permissions
prepare_files() {
  sudo touch "$LOG_FILE"
  sudo chmod 644 "$LOG_FILE"

  sudo mkdir -p "/var/secure" &>/dev/null  # Silently create directory if missing
  sudo touch "$PASSWORD_FILE"
  sudo chmod 600 "$PASSWORD_FILE"
}

# Log messages with timestamp
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Generate a random password
generate_password() {
  openssl rand -base64 12
}

# Create and manage users
create_user() {
  local username="$1"
  local groups="$2"

  # Check if the user already exists
  if id "$username" &>/dev/null; then
    log_message "User '$username' already exists. Skipping."
    return
  fi

  # Create user's personal group
  if ! sudo groupadd "$username"; then
    log_message "Failed to create group '$username'."
    return
  fi
  log_message "Created group '$username'."

  # Create user with home directory and group
  if ! sudo useradd -m -g "$username" -s /bin/bash "$username"; then
    log_message "Failed to create user '$username'."
    return
  fi
  log_message "Created user '$username' with home directory and personal group."

  # Set ownership of the home directory
  if ! sudo chown -R "$username:$username" "/home/$username"; then
    log_message "Failed to set ownership for /home/$username."
    return
  fi
  log_message "Set ownership for /home/$username."

  # Add user to additional groups (if any)
  if [[ -n "$groups" ]]; then
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"
    for group in "${GROUP_ARRAY[@]}"; do
      if ! getent group "$group" &>/dev/null; then
        if ! sudo groupadd "$group"; then
          log_message "Failed to create group '$group'."
          continue
        fi
        log_message "Created group '$group'."
      fi
      if ! sudo usermod -aG "$group" "$username"; then
        log_message "Failed to add user '$username' to group '$group'."
        continue
      fi
      log_message "Added user '$username' to group '$group'."
    done
  fi

  # Generate and set password
  local password
  password=$(generate_password)
  if ! echo "$username:$password" | sudo chpasswd; then
    log_message "Failed to set password for user '$username'."
    return
  fi
  log_message "Set password for user '$username'."

  # Store username and password securely
  echo "$username,$password" | sudo tee -a "$PASSWORD_FILE" >/dev/null
}

# Prepare log and password files
prepare_files

# Process user information from input file
while IFS=';' read -r username groups; do
  create_user "$username" "$groups"
done < "$1"

log_message "User creation process completed."
echo "User creation process completed. Check $LOG_FILE for details."