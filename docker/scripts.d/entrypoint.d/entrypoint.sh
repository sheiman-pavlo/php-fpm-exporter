#!/usr/bin/env bash

# Safer command execution:
#   -e Exit immediately if a command exits with a non-zero status.
#   -u Treat unset variables as an error when substituting.
set -eu

echo "Starting container entrypoint script with env:"
printenv

MAX_WAIT_TIME=600
SECONDS_ELAPSED=0

PHP_FPM_SCRAPE_PROTOCOL="${PHP_FPM_SCRAPE_URI%%://*}"
PHP_FPM_SCRAPE_ADDRESS="${PHP_FPM_SCRAPE_URI#*://}"

echo "PHP_FPM_SCRAPE_PROTOCOL=${PHP_FPM_SCRAPE_PROTOCOL}"
echo "PHP_FPM_SCRAPE_ADDRESS=${PHP_FPM_SCRAPE_ADDRESS}"

echo "[INFO] Will wait for [${PHP_FPM_SCRAPE_PROTOCOL}://${PHP_FPM_SCRAPE_ADDRESS}] socket availability."

handle_not_available() {
  echo "[NOTICE] Socket [${PHP_FPM_SCRAPE_PROTOCOL}://${PHP_FPM_SCRAPE_ADDRESS}] not yet available..."
  sleep 1

  SECONDS_ELAPSED=$((SECONDS_ELAPSED+1))

  if [ ${SECONDS_ELAPSED} -gt ${MAX_WAIT_TIME} ]; then
    echo "[FATAL] Timeout waiting for Unix socket."
    exit 1
  fi
}

case "${PHP_FPM_SCRAPE_PROTOCOL}" in
    "unix")
        PHP_FPM_SOCKET_PATH="${PHP_FPM_SCRAPE_ADDRESS%;*}"

        while ! echo -n | nc -U "${PHP_FPM_SOCKET_PATH}" >/dev/null 2>&1; do
            handle_not_available
        done
        ;;
    "tcp")
        IFS=':' read -r -a PHP_FPM_SCRAPE_HOST_PORT_PARTS <<< "${PHP_FPM_SCRAPE_ADDRESS}"

        PHP_FPM_SCRAPE_HOST="${PHP_FPM_SCRAPE_HOST_PORT_PARTS[0]}"
        PHP_FPM_SCRAPE_PORT="${PHP_FPM_SCRAPE_HOST_PORT_PARTS[1]%/*}"

        while ! nc -z "${PHP_FPM_SCRAPE_HOST}" "${PHP_FPM_SCRAPE_PORT}" >/dev/null 2>&1; do
          handle_not_available
        done
        ;;
    *)
        echo "Could not determine protocol from PHP_FPM_SCRAPE_URI: ${PHP_FPM_SCRAPE_URI}"
        exit 1

        ;;
esac

echo "[INFO] Socket [${PHP_FPM_SCRAPE_PROTOCOL}://${PHP_FPM_SCRAPE_ADDRESS}] became available, will continue to the container bootstrap..."
sleep 1

# Run the passed-in command in the current shell
CMD_STRING=$(echo "$*" | tr '\n' ' ')
printf "Executing entrypoint command [%s]\n" "${CMD_STRING::-1}"
exec "${@}"
