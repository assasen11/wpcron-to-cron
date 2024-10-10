#!/bin/bash

# Define the base frequency for WP-Cron jobs (every 15 minutes)
CRON_FREQUENCY_BASE="*/15 * * * *"

# Define the PHP path (adjust according to your server)
PHP_PATH="/usr/local/bin/php"

# Users to exclude from processing
EXCLUDED_USERS=("0_README_BEFORE_DELETING_VIRTFS" "clamav" "cPanelInstall" "temp" "virtfs")

# Log file name with iteration
LOG_DIR="/var/log/wpcron-to-cron"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/wpcron-to-cron-$(date '+%Y%m%d-%H%M%S').log"

# Store summaries to display and log at the end
declare -A CHANGES_PER_USER

# Global flag to auto-answer yes to all prompts
AUTO_YES=false

# Function to display help message
show_help() {
  echo "Usage: $0 [OPTION] [-y]"
  echo ""
  echo "Options:"
  echo "  --all                Apply cron job changes to all users"
  echo "  --user <username>    Apply cron job changes to a specific user"
  echo "  --all-spaced         Apply cron job changes to all WordPress sites, staggered at 5 sites per minute"
  echo "  --revert             Revert changes by re-enabling WP-Cron and removing cron jobs"
  echo "  -y                   Automatically answer yes to all prompts"
  echo "  --help               Display this help and exit"
  echo ""
  echo "This script disables WP-Cron in WordPress installations and sets up"
  echo "Linux cron jobs to run wp-cron.php on a regular basis."
  echo ""
  echo "Examples:"
  echo "  $0 --all              Apply cron job changes to all users"
  echo "  $0 --user username    Apply cron job changes to a specific user"
  echo "  $0 --all-spaced       Apply cron job changes to all WordPress sites but space cron jobs 5 sites per minute"
  echo "  $0 --revert           Revert changes by re-enabling WP-Cron and removing cron jobs"
  echo "  $0 --all -y           Apply cron jobs without any confirmations"
  exit 0
}

# Function to check if the cron job is already set
check_user_cron() {
  username="$1"
  wp_cron_path="$2"
  
  # Use grep -F for literal match to prevent issues with special characters
  if crontab -l -u "$username" 2>/dev/null | grep -F -q "$wp_cron_path"; then
    return 0
  else
    return 1
  fi
}

# Function to display the current cron jobs for the user
show_user_cron() {
  username="$1"

  echo "Current cron jobs for user: $username"
  if crontab -l -u "$username" 2>/dev/null | grep -q .; then
    crontab -l -u "$username"
  else
    echo "cron is empty"
  fi
}

# Function to apply cron jobs (disable WP-Cron and create new cron jobs)
apply_wordpress_site() {
  username="$1"
  wp_config_path="$2"
  wp_cron_path="${wp_config_path/wp-config.php/wp-cron.php}"
  cron_minute="$3"  # New argument to pass the staggered minute value

  if [[ "$AUTO_YES" = true ]]; then
    confirm="y"
  else
    # Prompt for confirmation before applying the site changes
    while true; do
      read -r -p "Do you want to apply changes for site: $wp_cron_path? (y/n) " confirm
      if [[ "$confirm" =~ ^[yY]$ || "$confirm" =~ ^[yY][eE][sS]$ || "$confirm" =~ ^[nN]$ || "$confirm" =~ ^[nN][oO]$ ]]; then
        break
      else
        echo "Invalid input. Please enter 'y' or 'n'."
      fi
    done
  fi

  if [[ "$confirm" =~ ^[yY]$ || "$confirm" =~ ^[yY][eE][sS]$ ]]; then
    # Disable WP-Cron by adding DISABLE_WP_CRON to wp-config.php if not already present
    if ! grep -q "DISABLE_WP_CRON" "$wp_config_path"; then
      echo "define('DISABLE_WP_CRON', true);" >> "$wp_config_path"
      echo "Disabled WP-Cron for site: $wp_cron_path"
      CHANGES_PER_USER["$username"]+="Disabled WP-Cron in $wp_config_path"$'\n'
    else
      echo "WP-Cron is already disabled for site: $wp_cron_path"
    fi

    # Add a cron job to the user's crontab to run wp-cron.php at the staggered time
    if ! check_user_cron "$username" "$wp_cron_path"; then
      (crontab -l -u "$username" 2>/dev/null; echo "$cron_minute */15 * * * $PHP_PATH $wp_cron_path > /dev/null 2>&1") | crontab -u "$username" -
      echo "Added cron job for site: $wp_cron_path"
      CHANGES_PER_USER["$username"]+="Added cron job for $wp_cron_path"$'\n'
    else
      echo "Cron job already exists for site: $wp_cron_path"
    fi
  else
    echo "Skipping changes for site: $wp_cron_path"
  fi
}

# Function to revert changes (re-enable WP-Cron and remove cron jobs)
revert_wordpress_site() {
  username="$1"
  wp_config_path="$2"
  wp_cron_path="${wp_config_path/wp-config.php/wp-cron.php}"

  if [[ "$AUTO_YES" = true ]]; then
    confirm="y"
  else
    # Prompt for confirmation before reverting the site
    while true; do
      read -r -p "Do you want to revert changes for site: $wp_cron_path? (y/n) " confirm
      if [[ "$confirm" =~ ^[yY]$ || "$confirm" =~ ^[yY][eE][sS]$ || "$confirm" =~ ^[nN]$ || "$confirm" =~ ^[nN][oO]$ ]]; then
        break
      else
        echo "Invalid input. Please enter 'y' or 'n'."
      fi
    done
  fi

  if [[ "$confirm" =~ ^[yY]$ || "$confirm" =~ ^[yY][eE][sS]$ ]]; then
    # Re-enable WP-Cron by removing the DISABLE_WP_CRON line
    if grep -q "DISABLE_WP_CRON" "$wp_config_path"; then
      sed -i "/define('DISABLE_WP_CRON', true);/d" "$wp_config_path"
      echo "Re-enabled WP-Cron for site: $wp_cron_path"
      CHANGES_PER_USER["$username"]+="Re-enabled WP-Cron in $wp_config_path"$'\n'
    else
      echo "WP-Cron was not disabled for site: $wp_cron_path"
    fi

    # Remove the cron job for the user
    if check_user_cron "$username" "$wp_cron_path"; then
      crontab -l -u "$username" | grep -F -v "$wp_cron_path" | crontab -u "$username" -
      echo "Removed cron job for site: $wp_cron_path"
      CHANGES_PER_USER["$username"]+="Removed cron job for $wp_cron_path"$'\n'
    else
      echo "No cron job found for site: $wp_cron_path"
    fi
  else
    echo "Skipping revert for site: $wp_cron_path"
  fi
}

# Function to apply cron jobs for all WordPress sites for a given user
apply_user() {
  username="$1"
  cron_minute="$2"  # Passed minute spacing

  echo "Applying cron job changes for WordPress installations of user: $username"

  # Use mapfile to safely handle paths with spaces
  mapfile -t wp_config_paths < <(find "/home/$username" -name "wp-config.php")

  for wp_config_path in "${wp_config_paths[@]}"; do
    echo "Found WordPress site at: $wp_config_path"
    
    apply_wordpress_site "$username" "$wp_config_path" "$cron_minute"
    cron_minute=$((cron_minute+5))  # Increment the minute by 5 for the next cron job
    if (( cron_minute >= 60 )); then cron_minute=0; fi  # Wrap around to 0 if we reach 60 minutes
  done

  # Show the current crontab after applying changes
  show_user_cron "$username"
}

# Function to revert all WordPress sites for a given user
revert_user() {
  username="$1"

  echo "Reverting changes for WordPress installations of user: $username"

  # Use mapfile to safely handle paths with spaces
  mapfile -t wp_config_paths < <(find "/home/$username" -name "wp-config.php")

  for wp_config_path in "${wp_config_paths[@]}"; do
    echo "Found WordPress site at: $wp_config_path"
    revert_wordpress_site "$username" "$wp_config_path"
  done

  # Show the current crontab after reverting all sites for the user
  show_user_cron "$username"
}

# Function to log and display the summary of changes
log_changes() {
  echo "Summary of Changes:" | tee "$LOG_FILE"
  for user in "${!CHANGES_PER_USER[@]}"; do
    echo -e "User: $user\n${CHANGES_PER_USER[$user]}" | tee -a "$LOG_FILE"
  done
  echo "Log saved to: $LOG_FILE" | tee -a "$LOG_FILE"
}

# Parse arguments to set options like -y (auto-yes)
for arg in "$@"; do
  if [[ "$arg" == "-y" ]]; then
    AUTO_YES=true
  fi
done

# Main script logic
if [[ "$1" == "--all" ]]; then
  # Apply cron jobs for all users, excluding some system users
  for user_dir in /home/*; do
    username=$(basename "$user_dir")
    if [[ " ${EXCLUDED_USERS[*]} " == *" $username "* ]]; then
      echo "Skipping excluded user: $username"
      continue
    fi
    echo "Processing user: $username"
    apply_user "$username" 0
  done
  log_changes

elif [[ "$1" == "--user" && -n "$2" ]]; then
  # Apply cron jobs for a specific user
  username="$2"
  if [ -d "/home/$username" ]; then
    echo "Processing user: $username"
    apply_user "$username" 0
  else
    echo "User $username does not exist."
  fi
  log_changes

elif [[ "$1" == "--all-spaced" ]]; then
  # Apply cron jobs for all users, staggering jobs across multiple users, excluding some system users
  cron_minute=0
  for user_dir in /home/*; do
    username=$(basename "$user_dir")
    if [[ " ${EXCLUDED_USERS[*]} " == *" $username "* ]]; then
      echo "Skipping excluded user: $username"
      continue
    fi
    echo "Processing user: $username"
    apply_user "$username" "$cron_minute"
    ((cron_minute=(cron_minute+5)%60))
  done
  log_changes

elif [[ "$1" == "--revert" ]]; then
  # Revert changes for all users, excluding some system users
  for user_dir in /home/*; do
    username=$(basename "$user_dir")
    if [[ " ${EXCLUDED_USERS[*]} " == *" $username "* ]]; then
      echo "Skipping excluded user: $username"
      continue
    fi
    echo "Reverting changes for user: $username"
    revert_user "$username"
  done
  log_changes

elif [[ "$1" == "--help" ]]; then
  # Display help information
  show_help

else
  echo "Invalid option: $1"
  echo "Use --help for usage information."
  exit 1
fi
