# wpcron-to-cron
Convert a cpanel user or users from wpcron to cron


# WP-Cron to Linux Cron Script

This script disables WP-Cron in WordPress installations and sets up Linux cron jobs to run `wp-cron.php` on a regular basis. It provides various options to apply cron jobs for all users, specific users, and to stagger cron job execution times for better performance and load distribution. It also allows automatic reversion of the changes if needed.

## Usage

```bash
./wpcron-to-cron.sh [OPTION] [-y]
```

## Options

- **`--all`**  
  Apply cron job changes to all users.

- **`--user <username>`**  
  Apply cron job changes to a specific user.

- **`--all-spaced`**  
  Apply cron job changes to all WordPress sites, staggered at 5 sites per minute.

- **`--revert`**  
  Revert changes by re-enabling WP-Cron and removing cron jobs.

- **`-y`**  
  Automatically answer "yes" to all prompts. Useful when running non-interactively.

- **`--help`**  
  Display help and exit.

## Examples

- Apply cron job changes to all users:
  ```bash
  ./wpcron-to-cron.sh --all
  ```

- Apply cron job changes to a specific user:
  ```bash
  ./wpcron-to-cron.sh --user username
  ```

- Apply cron job changes to all WordPress sites, staggered at 5 sites per minute:
  ```bash
  ./wpcron-to-cron.sh --all-spaced
  ```

- Revert changes by re-enabling WP-Cron and removing cron jobs:
  ```bash
  ./wpcron-to-cron.sh --revert
  ```

- Apply cron jobs without any confirmations:
  ```bash
  ./wpcron-to-cron.sh --all -y
  ```

---

This script helps reduce server load by using Linux's more reliable cron system, while also offering flexibility for reverting changes or staggering cron jobs.
