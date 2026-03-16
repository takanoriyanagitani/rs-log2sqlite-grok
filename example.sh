#!/bin/sh

WASM="./log2sqlite-grok.wasm"
BIN="./log2sqlite-grok"

DBNAME="./test.sqlite.db"

GDBNAME="/guest.d/write/test.sqlite.db"
GDIR="/guest.d/write"
HDIR="${PWD}"

input() {
	echo 'strange 1st log with no timestamp'
	echo 'strange log with timestamp 2026-03-10T15:01:46.012Z'
	echo 'log with time zone 2026-03-11T15:01:58.012+09:00'
	echo '[2026-03-12T15:01:58.012Z INFO systemd] apt update done'
	echo 'tiem:2026-03-13T15:01:58.012Z	severity:INFO	body:apt update done'
	echo 'last log with no timestamp'
}

initsql="
    CREATE TABLE IF NOT EXISTS log_raw (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp BLOB NULL,
        body BLOB NULL
    );
  
    CREATE INDEX IF NOT EXISTS log_raw_notime
    ON log_raw(id) WHERE timestamp IS NULL;
  
    CREATE INDEX IF NOT EXISTS log_raw_prev
    ON log_raw(id, timestamp) WHERE timestamp IS NOT NULL;
"

insertsql="
    INSERT INTO log_raw (timestamp, body)
    VALUES (?, ?)
"

run_native() {
	test -f "${BIN}" || exec env bin="${BIN}" sh -c '
        echo native binary "${bin}" missing.
        exit 1
    '

	echo converting the test log to sqlite...

	input |
		"${BIN}" \
			--init-sql="${initsql}" \
			--insert-sql="${insertsql}" \
			--output-dbname="${DBNAME}"
}

run_wasi() {
	test -f "${WASM}" || exec env wsm="${WASM}" sh -c '
        echo wasm byte code "${wsm}" missing.
        exit 1
    '

	echo converting the test log to sqlite...

	input |
        wasmtime \
            run \
            --dir "${HDIR}::${GDIR}" \
		    "${WASM}" \
			--init-sql="${initsql}" \
			--insert-sql="${insertsql}" \
			--output-dbname="${GDBNAME}"
}

test -f "${DBNAME}" || run_wasi
echo

echo original log before fill
sqlite3 -table "${DBNAME}" "SELECT * FROM log_raw"
echo

echo updating the log...
sqlite3 -table "${DBNAME}" "
    UPDATE log_raw
    SET timestamp=(
        SELECT timestamp FROM log_raw AS il
        WHERE il.id < log_raw.id
          AND il.timestamp IS NOT NULL
        ORDER BY il.id DESC
        LIMIT 1
    )
    WHERE timestamp IS NULL
"
echo

echo updated log
sqlite3 -table "${DBNAME}" "SELECT * FROM log_raw"
