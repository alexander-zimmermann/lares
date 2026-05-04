#!/bin/sh
set -eu

# Required environment variables:
#   BUCKETS                              - space-separated list of bucket names to create
#   RCLONE_CONFIG_RUSTFS_*               - rclone S3 remote config (endpoint, keys, etc.)

for BUCKET in $BUCKETS; do
  rclone mkdir "rustfs:$BUCKET"
done

echo "Done"
