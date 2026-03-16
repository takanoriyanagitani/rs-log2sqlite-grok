use std::io;
use std::process::ExitCode;

use io::BufRead;

use clap::Parser;
use grok::Grok;
use grok::Pattern;

use rusqlite::Connection;

use rs_log2sqlite_grok::parse::add_pattern_default;
use rs_log2sqlite_grok::parse::pattern2timestamp_utf8_only;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    #[arg(long)]
    init_sql: String,

    #[arg(long)]
    insert_sql: String,

    #[arg(long)]
    output_dbname: String,

    #[arg(long, default_value = "%{TIMESTAMP_ISO8601:timestamp}")]
    timestamp_pattern: String,
}

fn sub() -> Result<(), io::Error> {
    let args = Args::parse();

    let mut g = Grok::default();
    add_pattern_default(&mut g);
    let pat: Pattern = g
        .compile(&args.timestamp_pattern, true)
        .map_err(io::Error::other)?;

    let lines = io::stdin().lock().split(b'\n');

    let mut conn = Connection::open(&args.output_dbname).map_err(io::Error::other)?;

    conn.execute_batch(&args.init_sql)
        .map_err(io::Error::other)?;

    let tx = conn.transaction().map_err(io::Error::other)?;

    {
        let mut stmt = tx.prepare(&args.insert_sql).map_err(io::Error::other)?;

        let mut buf: String = String::new();
        for rline in lines {
            buf.clear();

            let line: Vec<u8> = rline?;
            pattern2timestamp_utf8_only(&pat, &line, &mut buf);

            let notime: bool = buf.is_empty();
            let oktime: bool = !notime;
            let btime: &[u8] = buf.as_bytes();
            let otime: Option<&[u8]> = oktime.then_some(btime);

            stmt.execute((otime, &line)).map_err(io::Error::other)?;
        }
    }

    tx.commit().map_err(io::Error::other)?;

    conn.close().map_err(|tup| tup.1).map_err(io::Error::other)
}

fn main() -> ExitCode {
    sub().map(|_| ExitCode::SUCCESS).unwrap_or_else(|e| {
        eprintln!("{e}");
        ExitCode::FAILURE
    })
}
