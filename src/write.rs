use std::io;

use rusqlite::Statement;

use crate::log::LogBasic;

pub fn insert2sqlite(log: &LogBasic, stmt: &mut Statement) -> Result<(), io::Error> {
    let timestamp_us: i64 = log.unixtime_us;
    let message_data: &[u8] = log.message_data;

    stmt.execute((timestamp_us, message_data))
        .map_err(io::Error::other)
        .map(|_| ())
}
