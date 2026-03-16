use std::io;
use std::process::ExitCode;

use io::BufRead;

use io::BufWriter;
use io::Write;

use clap::Parser;
use grok::Grok;
use grok::Pattern;

use rs_log2sqlite_grok::parse::add_pattern_default;
use rs_log2sqlite_grok::parse::pattern2timestamp_utf8_only;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
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

    let o = io::stdout();
    let mut ol = o.lock();
    let mut bw = BufWriter::new(&mut ol);

    let mut buf: String = String::new();
    for rline in lines {
        buf.clear();

        let line: Vec<u8> = rline?;
        pattern2timestamp_utf8_only(&pat, &line, &mut buf);
        let sline: &str = std::str::from_utf8(&line).unwrap_or_default();
        writeln!(&mut bw, "time:{buf}\tbody:{sline}")?;
    }
    bw.flush()?;
    drop(bw);
    ol.flush()
}

fn main() -> ExitCode {
    sub().map(|_| ExitCode::SUCCESS).unwrap_or_else(|e| {
        eprintln!("{e}");
        ExitCode::FAILURE
    })
}
