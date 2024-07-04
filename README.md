# User Creation Bash Script

Managing users on a Unix-like system can become a complex task, especially when dealing with large-scale deployments. Automating this process can save time and reduce errors. In this article, we’ll dive into a Bash script designed for automated user management, including user creation, group assignment, and password management. This script ensures proper logging and secure password storage, making it an ideal solution for SysOps engineers.



### Overview of Script

The script performs the following tasks:

	1.	Prepare log and password files: Sets up necessary files with appropriate permissions.
	2.	Log messages: Records actions and errors with timestamps.
	3.	Generate random passwords: Creates secure passwords for new users.
	4.	Create and manage users: Adds users, assigns groups, and stores passwords securely.

```bash
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
```
Let's breakdown the script to understand the functionality of each section.

### Defining File Paths
```bash
# Define file paths
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"
```
__Explanation:__

-	`LOG_FILE:` Variable that store the file path for log file.
-  `PASSWORD_FILE:` Variable that store the file path password file.

### Preparing Files
```bash
# Create log and password files with proper permissions
prepare_files() {
  sudo touch "$LOG_FILE"
  sudo chmod 644 "$LOG_FILE"

  sudo mkdir -p "/var/secure" &>/dev/null  # Silently create directory if missing
  sudo touch "$PASSWORD_FILE"
  sudo chmod 600 "$PASSWORD_FILE"
}
```
__Explanation:__

-	`sudo touch "$LOG_FILE":` Creates the log file if it doesn’t exist.
-	`sudo chmod 644 "$LOG_FILE":` Sets the permissions of the log file to be readable and writable by the owner, and readable by others.
-	`sudo mkdir -p "/var/secure" &>/dev/null:` Creates the /var/secure directory if it doesn’t exist, suppressing any errors or messages.
-	`sudo touch "$PASSWORD_FILE":` Creates the password file if it doesn’t exist.
-	`sudo chmod 600 "$PASSWORD_FILE":` Sets the permissions of the password file to be readable and writable only by the owner.

### Logging Messages
```bash
# Log messages with timestamp
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$LOG_FILE" >/dev/null
}
```
__Explanation:__
-	`date '+%Y-%m-%d %H:%M:%S':` Gets the current date and time in the specified format.
-	`sudo tee -a`: Appends the message to the log file with elevated privileges.
`$1` represents the first argument passed to the function.

### Generating Random Passwords
```bash
# Generate a random password
generate_password() {
  openssl rand -base64 12
}
```
__Explanation:__
-	`openssl rand -base64 12:` Generates a 12-character random string encoded in base64.

### Creating and Managing Users
```bash
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
```
__Explanation:__
-	`local username="$1" and local groups="$2":` These lines define local variables username and groups, assigned to the first and second arguments passed to the function.

-	`if id "$username" &>/dev/null; then:` Checks if the user already exists. The id command returns user ID information; if it succeeds, the user exists.

-	`log_message "User '$username' already exists. Skipping.":` Logs a message if the user already exists.

-	`return:` Exits the function if the user exists.

-	`if ! sudo groupadd "$username"; then:` Attempts to create a group with the username. The ! operator negates the exit status.

-	`log_message "Failed to create group ‘$username’.":` Logs a message if group creation fails.

-	`return:` Exits the function if group creation fails.

-	`log_message "Created group ‘$username’.":` Logs a message indicating the group was successfully created.

-	`if ! sudo useradd -m -g "$username" -s /bin/bash "$username"; then:` Attempts to create the user with a home directory (-m), a specific group (-g), and the bash shell (-s) and assigns the personal group as the primary group.

-	`log_message "Failed to create user ‘$username’.":` Logs a message if user creation fails.

-	`return:` Exits the function if user creation fails.

-	`log_message "Created user ‘$username’ with home directory and personal group.":` Logs a message indicating the user was successfully created.

- `sudo chown -R “$username:$username” “/home/$username”:` Sets the ownership of the home directory to the new user.

-	`if [[ -n "$groups" ]]; then:` Checks if additional groups were specified.

-	`IFS=',' read -ra GROUP_ARRAY <<< "$groups":` Splits the groups string into an array using commas as delimiters.

-	`for group in "${GROUP_ARRAY[@]}"; do:` Iterates over the groups in the array.

-	`if ! getent group "$group" &>/dev/null; then:` Checks if the group exists.

-	`if ! sudo groupadd "$group"; then:` Attempts to create the group if it doesn’t exist.

-	`log_message "Failed to create group ‘$group’.":` Logs a message if group creation fails.

-	`continue:` Skips to the next iteration if group creation fails.

-	`log_message "Created group ‘$group’.":` Logs a message indicating the group was successfully created.

-	`if ! sudo usermod -aG "$group" "$username"; then:` Adds the user to the group.

-	`log_message "Failed to add user ‘$username’ to group ‘$group’.":` Logs a message if adding the user to the group fails.

-	`continue:` Skips to the next iteration if adding the user to the group fails.

-	`log_message "Added user ‘$username’ to group ‘$group’.":` Logs a message indicating the user was successfully added to the group.

-	`local password:` Defines a local variable password.

-	`password=$(generate_password):` Generates a random password and assigns it to the password variable.

-	`if ! echo "$username:$password" | sudo chpasswd; then:` Sets the user’s password.

-	`log_message "Failed to set password for user ‘$username’.":` Logs a message if setting the password fails.

-	`return:` Exits the function if setting the password fails.

-	`log_message "Set password for user ‘$username’.":` Logs a message indicating the password was successfully set.

-	`echo "$username,$password" | sudo tee -a “$PASSWORD_FILE” >/dev/null:` Appends the username and password to the password file.

### Processing User Information
Finally, the script processes user information from an input file and calls create_user for each user:
```bash
# Process user information from input file
while IFS=';' read -r username groups; do
  create_user "$username" "$groups"
done < "$1"

log_message "User creation process completed."
echo "User creation process completed. Check $LOG_FILE for details."
```
__Explanation:__

-	`while IFS=';' read -r username groups; do:` Reads lines from the input file, using ; as the delimiter to separate username and groups.
-	`create_user "$username" "$groups":` Calls the create_user function with the username and groups as arguments.
-	`done < "$1":` The done keyword ends the while loop. $1 represents the first argument passed to the script, which should be the path to the input file.
-	`log_message "User creation process completed.":` Logs a message indicating the user creation process is complete.
-	`echo "User creation process completed. Check $LOG_FILE for details.":` Prints a message to the console indicating completion and directing the user to the log file for details.

__Conclusion__


This script helps to automate management of user in a UNIX system. 


This script provides a robust solution for automating user management on Unix-like systems. 
It ensures secure handling of user credentials and maintains detailed logs for administrative purposes.
[HNG Internship](https://hng.tech/internship) program and [HNG premium services](https://hng.tech/premium) has helped in making sure that this well detailed task was carried out by the interns.
 

By following these guidelines, you can enhance your system administration tasks and maintain a secure and well-organized user management process.