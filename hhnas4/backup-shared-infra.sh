#!/usr/bin/env bash
# shellcheck disable=SC2029
set -euo pipefail

usage() {
	cat <<'USAGE'
Usage:
  backup-shared-infra.sh [target-host] [remote-base-dir] [--retention-days N]

Examples:
  ./backup-shared-infra.sh nas-host
  ./backup-shared-infra.sh nas-host /volume1/docker/homelab/nas-host
  ./backup-shared-infra.sh nas-host --retention-days 21
USAGE
}

TARGET_HOST="nas-host"
REMOTE_BASE_DIR="/volume1/docker/homelab/nas-host"
RETENTION_DAYS=14

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
	TARGET_HOST="$1"
	shift
fi

if [[ "${1:-}" != "" && "${1:-}" != --* ]]; then
	REMOTE_BASE_DIR="$1"
	shift
fi

while [[ $# -gt 0 ]]; do
	case "$1" in
	--retention-days)
		if [[ -z "${2:-}" || ! "${2:-}" =~ ^[0-9]+$ ]]; then
			echo "[backup] --retention-days requires an integer value" >&2
			exit 2
		fi
		RETENTION_DAYS="$2"
		shift 2
		;;
	*)
		echo "[backup] unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

TIMESTAMP_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
REMOTE_BACKUP_ROOT="${REMOTE_BASE_DIR}/backups/shared-infra"
REMOTE_BACKUP_DIR="${REMOTE_BACKUP_ROOT}/${TIMESTAMP_UTC}"

echo "[backup] target host      : ${TARGET_HOST}"
echo "[backup] remote base dir  : ${REMOTE_BASE_DIR}"
echo "[backup] backup root      : ${REMOTE_BACKUP_ROOT}"
echo "[backup] backup timestamp : ${TIMESTAMP_UTC}"
echo "[backup] retention days   : ${RETENTION_DAYS}"

DOCKER_BIN="$(
	ssh "${TARGET_HOST}" "command -v docker || { test -x /usr/local/bin/docker && echo /usr/local/bin/docker; } || { test -x /var/packages/ContainerManager/target/usr/bin/docker && echo /var/packages/ContainerManager/target/usr/bin/docker; } || { test -x /var/packages/Docker/target/usr/bin/docker && echo /var/packages/Docker/target/usr/bin/docker; }"
)"

if [[ -z "${DOCKER_BIN}" ]]; then
	echo "[backup] could not find docker binary on ${TARGET_HOST}" >&2
	exit 1
fi

if ssh "${TARGET_HOST}" "${DOCKER_BIN} info >/dev/null 2>&1"; then
	DOCKER_PREFIX=""
elif ssh "${TARGET_HOST}" "sudo -n ${DOCKER_BIN} info >/dev/null 2>&1"; then
	DOCKER_PREFIX="sudo -n "
else
	DOCKER_PREFIX="sudo "
fi

ssh "${TARGET_HOST}" "mkdir -p '${REMOTE_BACKUP_DIR}/postgres' '${REMOTE_BACKUP_DIR}/mysql' '${REMOTE_BACKUP_DIR}/redis'"

echo "[backup] dumping postgres (pg_dumpall)"
ssh "${TARGET_HOST}" "cd '${REMOTE_BASE_DIR}/postgres' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec -T postgres pg_dumpall -U postgres | gzip -c > '${REMOTE_BACKUP_DIR}/postgres/pg_dumpall.sql.gz'"

echo "[backup] dumping mysql (all databases)"
ssh "${TARGET_HOST}" "cd '${REMOTE_BASE_DIR}/ghost-mysql' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec -T mysql sh -lc 'exec mysqldump --all-databases --single-transaction --routines --events --triggers -uroot -p\"\$MYSQL_ROOT_PASSWORD\"' | gzip -c > '${REMOTE_BACKUP_DIR}/mysql/all-databases.sql.gz'"

echo "[backup] exporting redis RDB snapshot"
ssh "${TARGET_HOST}" "cd '${REMOTE_BASE_DIR}/redis' && ${DOCKER_PREFIX}${DOCKER_BIN} compose exec -T redis sh -lc 'redis-cli -h 127.0.0.1 -p \"\${REDIS_PORT:-6379}\" --user \"\$REDIS_ADMIN_USERNAME\" --pass \"\$REDIS_ADMIN_PASSWORD\" --rdb /tmp/redis-backup.rdb >/dev/null && cat /tmp/redis-backup.rdb && rm -f /tmp/redis-backup.rdb' > '${REMOTE_BACKUP_DIR}/redis/redis.rdb'"

echo "[backup] writing checksums and manifest"
ssh "${TARGET_HOST}" "cd '${REMOTE_BACKUP_DIR}' && sha256sum postgres/pg_dumpall.sql.gz mysql/all-databases.sql.gz redis/redis.rdb > SHA256SUMS"
ssh "${TARGET_HOST}" "cat > '${REMOTE_BACKUP_DIR}/MANIFEST.txt' <<EOF
timestamp_utc=${TIMESTAMP_UTC}
backup_root=${REMOTE_BACKUP_ROOT}
retention_days=${RETENTION_DAYS}
target_host=${TARGET_HOST}
docker_bin=${DOCKER_BIN}
docker_prefix=${DOCKER_PREFIX}
postgres_dump=postgres/pg_dumpall.sql.gz
mysql_dump=mysql/all-databases.sql.gz
redis_rdb=redis/redis.rdb
checksums=SHA256SUMS
EOF"

echo "[backup] pruning backups older than ${RETENTION_DAYS} days"
ssh "${TARGET_HOST}" "find '${REMOTE_BACKUP_ROOT}' -mindepth 1 -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -print0 | xargs -0r rm -rf --"

echo "[backup] done."
echo "[backup] latest backup dir: ${REMOTE_BACKUP_DIR}"
echo "[backup] quick check:"
echo "         ssh ${TARGET_HOST} \"ls -lah '${REMOTE_BACKUP_DIR}' '${REMOTE_BACKUP_DIR}/postgres' '${REMOTE_BACKUP_DIR}/mysql' '${REMOTE_BACKUP_DIR}/redis'\""
