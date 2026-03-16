use grok::Grok;
use grok::Pattern;

pub fn pattern2timestamp_utf8_only(pat: &Pattern, line: &[u8], tsbuf: &mut String) -> Option<()> {
    let ostr: Option<_> = std::str::from_utf8(line).ok();
    let s: &str = ostr.unwrap_or_default();
    let omat: Option<_> = pat.match_against(s);
    let mat = omat?;
    let mut imat = mat.iter();
    let opair: Option<_> = imat.next();
    let pair = opair?;
    let (_, val) = pair;

    tsbuf.push_str(val);
    Some(())
}

pub const TIMESTAMP_NAME_DEFAULT: &str = "timestamp";
pub const TIMESTAMP_PATTERN_DEFAULT: &str = "%{TIMESTAMP_ISO8601:timestamp}";

pub fn add_pattern<S>(g: &mut Grok, name: S, pattern: S)
where
    S: Into<String>,
{
    g.add_pattern(name, pattern)
}

pub fn add_pattern_default_name(g: &mut Grok, pattern: &str) {
    add_pattern(g, TIMESTAMP_NAME_DEFAULT, pattern)
}

pub fn add_pattern_default(g: &mut Grok) {
    add_pattern_default_name(g, TIMESTAMP_PATTERN_DEFAULT)
}
