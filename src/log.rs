pub struct LogBasic<'a> {
    pub unixtime_us: i64,
    pub message_data: &'a [u8],
}
