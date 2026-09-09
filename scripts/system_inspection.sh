#!/bin/bash

LOG_FILE="/var/log/system_inspection.log"
WARN_COUNT=0
FAIL_COUNT=0

log_message(){
	local level="$1"
	shift
	local message="$*"
	local line="[$(date '+%F %T')] [$level] $message"

	echo "$line"
	echo "$line" >> "$LOG_FILE"
}

check_service(){
	local service="$1"

	if systemctl is-active --quiet "$service"; then
		log_message OK "service $service is active"
	else
		log_message FAIL "service $service is not active"
		FAIL_COUNT=$((FAIL_COUNT + 1))
	fi
}

check_http(){
	local name="$1"
	local url="$2"
	local http_code
	
	http_code=$(curl --connect-timeout 5 --max-time 10 \
	-o /dev/null -sS -w "%{http_code}" "$url")

	if [ "$http_code" = "200" ]; then
		log_message OK "http $name status=$http_code"
	else
		log_message FAIL "http $name status=$http_code url=$url"
		FAIL_COUNT=$((FAIL_COUNT + 1))
	fi
}

check_memory(){
	local total available available_pct

	total=$(free -m | awk '/^Mem:/ {print $2}')
	available=$(free -m | awk '/^Mem:/ {print $7}')

	if [ -z "$total" ] || [ "$total" -eq 0 ] || [ -z "$available" ]; then
		log_message FAIL "memory metrics unavailable"
		FAIL_COUNT=$((FAIL_COUNT + 1))
		return
	 fi

	available_pct=$((available * 100 / total))

	if [ "$available_pct" -lt 20 ]; then
		log_message WARN "memory available=${available_pct}%"			
		WARN_COUNT=$((WARN_COUNT + 1))
	else
		log_message OK "memory available=${available_pct}%"
	fi
}

check_filesystem(){
	local usage inode_usage

	usage=$(df -P / | awk 'NR==2 {gsub(/%/,"",$5);print $5}')
	inode_usage=$(df -Pi / | awk 'NR==2 {gsub(/%/,"",$5);print $5}')

	if [ -z "$usage" ] || [ -z "$inode_usage" ];then
		log_message FAIL "filesystem metrics unavailable"
		FAIL_COUNT=$((FAIL_COUNT + 1))
		return
	fi

	if [ "$usage" -ge 80 ];then
		log_message WARN "root filesystem usage=${usage}%"
		WARN_COUNT=$((WARN_COUNT + 1))
	else
		log_message OK "root filesystem usage=${usage}%"
	fi

	if [ "$inode_usage" -ge 80 ];then
                log_message WARN "root filesystem usage=${inode_usage}%"
                WARN_COUNT=$((WARN_COUNT + 1))
        else
                log_message OK "root filesystem inode_usage=${inode_usage}%"
        fi
}

log_message INFO "inspection started: script=system_inspection"

for service in nginx mariadb backend-demo crond firewalld sshd; do
	check_service "$service"
done

check_http nginx "http://127.0.0.1"
check_http backend "http://127.0.0.1:8080"

check_memory
check_filesystem

log_message INFO "inspection finished: warned=${WARN_COUNT} failed=${FAIL_COUNT}"

if [ "$FAIL_COUNT" -gt 0 ]; then
	exit 2
elif [ "$WARN_COUNT" -gt 0 ]; then
	exit 1
else
	exit 0
fi









