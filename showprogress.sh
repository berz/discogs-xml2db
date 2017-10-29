#!/usr/bin/env bash

# This program script provides an progress overview of the importing progress
# using common linux tools to read data from the proc filesystem.

# crash on errors
set -euo pipefail
IFS=$'\n\t'

PROGRAM_NAME="discogsparser.py"
FILE_EXTENSION="xml"
HOST="localhost"
PORT="5433"
USER="discogs"
DATABASE="discogs"
SCHEMA="discogs"

echo "Current file"
echo "------------"
echo ""
pid=$(pgrep -f $PROGRAM_NAME | tail -n 1 || true)
if [[ ! -z  $pid ]]; then
	fd=$(find /proc/$pid/fd -lname \*.$FILE_EXTENSION | sed 's|.*/||')

	file=$(realpath /proc/$pid/fd/$fd)

	pos=$(cat /proc/$pid/fdinfo/$fd | grep pos | cut -f2)
	total=$(wc -c /proc/$pid/fd/$fd | cut -f1 -d' ')
	progress=$(echo "scale=3; 100*$pos/$total" | bc)

	start=$(date -d "$(ps -o lstart= -p $pid)" +%s)
	now=$(date +%s)
	elasped=$(echo $now - $start | bc)
	estimated_total_duration=$(echo "scale=3; (100 / $progress) * $elasped" | bc)
	end=$(echo "$start + $estimated_total_duration" | bc)

	echo "file: $file"
	echo "progress:          $progress %"
	printf 'current position: %12s B\n' $pos
	printf 'file size:        %12s B\n' $total
	echo "started at:        $(date -d @$start +'%Y-%m-%d %H:%M:%S')"
	echo "estimated end:     $(date -d @$end   +'%Y-%m-%d %H:%M:%S')"
else
	echo "no $PROGRAM_NAME process found"
fi

echo ""
echo "Database tables"
echo "----------------"
echo ""
psql -U "$USER" -d "$DATABASE" -c "
	select table_name, to_char(pg_relation_size(table_name), '999G999G999G999')
	from information_schema.tables
	where table_schema='$SCHEMA'
	order by table_name;" | sed 's/to_char/entries/'
