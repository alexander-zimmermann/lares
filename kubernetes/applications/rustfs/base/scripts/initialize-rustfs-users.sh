#!/bin/sh
set -eu

# Provisions per-app, bucket-scoped RustFS IAM users. Each consumer
# gets its own access key with a least-privilege policy limited to its own bucket;
# the shared admin key stays only for in-namespace operators (bucket-init,
# nats-archive compactor).
#
# The `rc admin` verbs are naturally idempotent (user add / policy create /
# policy attach all exit 0 on repeat — verified against rustfs 1.0.0-beta.7), so
# this runs cleanly on every PostSync and `set -eu` still surfaces real failures.
# IAM state persists on the data PVC across pod restarts (verified).
#
# Credentials arrive as env vars via envFrom prefixes (ADMIN_, AUTHENTIK_, …).
# HOME=/tmp keeps rc's config on the writable emptyDir under the read-only root fs.

EP="http://rustfs-svc.rustfs.svc.cluster.local:9000"
rc alias set admin "$EP" "$ADMIN_RUSTFS_ACCESS_KEY" "$ADMIN_RUSTFS_SECRET_KEY"

# provision <slug> <bucket> <readwrite|writeonly> <access-key> <secret-key>
provision() {
  slug=$1
  bucket=$2
  mode=$3
  ak=$4
  sk=$5
  echo ">>> user='$ak' bucket='$bucket' mode='$mode'"
  rc admin user add admin "$ak" "$sk"
  if [ "$mode" = "writeonly" ]; then
    cat > /tmp/policy.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:PutObject"],"Resource":["arn:aws:s3:::${bucket}/*"]}]}
EOF
  else
    cat > /tmp/policy.json <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket","s3:GetBucketLocation"],"Resource":["arn:aws:s3:::${bucket}","arn:aws:s3:::${bucket}/*"]}]}
EOF
  fi
  rc admin policy create admin "${slug}-scoped" /tmp/policy.json
  rc admin policy attach admin "${slug}-scoped" --user "$ak"
}

provision authentik           authentik-backups     readwrite "$AUTHENTIK_RUSTFS_ACCESS_KEY"   "$AUTHENTIK_RUSTFS_SECRET_KEY"
provision wiki-js             wiki-js-backups       readwrite "$WIKIJS_RUSTFS_ACCESS_KEY"      "$WIKIJS_RUSTFS_SECRET_KEY"
provision timescaledb         timescaledb-backups   readwrite "$TIMESCALEDB_RUSTFS_ACCESS_KEY" "$TIMESCALEDB_RUSTFS_SECRET_KEY"
provision redpanda-connect    nats-archive          writeonly "$REDPANDA_RUSTFS_ACCESS_KEY"    "$REDPANDA_RUSTFS_SECRET_KEY"

echo ">>> done; current users:"
rc admin user ls admin
