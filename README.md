# wpcron-to-cron
Convert a cpanel user or users from wpcron to cron


Usage: ./wpcron-to-cron1.sh [OPTION]

Options:
  --all                Apply cron job changes to all users
  --user <username>    Apply cron job changes to a specific user
  --all-spaced         Apply cron job changes to all WordPress sites, staggered at 5 sites per minute
  --revert             Revert changes by re-enabling WP-Cron and removing cron jobs
  --help               Display this help and exit

This script disables WP-Cron in WordPress installations and sets up
Linux cron jobs to run wp-cron.php on a regular basis.

Examples:
  ./wpcron-to-cron1.sh --all              Apply cron job changes to all users
  ./wpcron-to-cron1.sh --user username    Apply cron job changes to a specific user
  ./wpcron-to-cron1.sh --all-spaced       Apply cron job changes to all WordPress sites but space cron jobs 5 sites per minute
  ./wpcron-to-cron1.sh --revert           Revert changes by re-enabling WP-Cron and removing cron jobs
