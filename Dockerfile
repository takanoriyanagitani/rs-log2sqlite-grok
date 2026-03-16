FROM rust:1.94.0-alpine3.23 AS builder
RUN rustup target add wasm32-wasip1
RUN apk update

WORKDIR /rs-log2sqlite-grok
RUN apk add clang21
RUN apk add cmake
RUN apk add ninja
RUN apk add python3
RUN apk add wasi-sdk
RUN apk add musl-dev
COPY --link ./Cargo.toml ./
COPY --link ./Cargo.lock ./
RUN mkdir -p src/bin
RUN echo 'fn main(){}' > ./src/main.rs
RUN echo 'fn main(){}' > ./src/bin/log2sqlite-grok.rs
RUN echo 'fn main(){}' > ./src/bin/log2parsed.rs
RUN touch ./src/lib.rs
RUN cargo check --features log2sqlite
ENV CFLAGS='-I/usr/share/wasi-sysroot/include/wasm32-wasip1'
COPY --link ./src/ ./src/
RUN touch ./src/lib.rs
RUN touch ./src/main.rs
RUN cargo build --target wasm32-wasip1 --profile release-wasi --bin log2sqlite-grok --bin log2parsed --features log2sqlite
RUN cp target/wasm32-wasip1/release-wasi/log2sqlite-grok.wasm /usr/local/bin/
RUN cp target/wasm32-wasip1/release-wasi/log2parsed.wasm /usr/local/bin/

FROM golang:1.26.1-alpine3.23 AS demo
RUN go install -v github.com/tetratelabs/wazero/cmd/wazero@v1.11.0
COPY --link --from=builder /usr/local/bin/log2sqlite-grok.wasm /
COPY --link --from=builder /usr/local/bin/log2parsed.wasm /
RUN apk add sqlite
RUN printf '2026-03-10T15:01:46.012Z example log\n' > input.log
RUN cat input.log | \
    wazero \
        run \
        -mount .:/guest.d \
        /log2sqlite-grok.wasm \
        -- \
        --init-sql="CREATE TABLE IF NOT EXISTS log_raw (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp BLOB NULL, body BLOB NULL);" \
        --insert-sql="INSERT INTO log_raw (timestamp, body) VALUES (?, ?)" \
        --output-dbname="/guest.d/test.sqlite.db"
RUN sqlite3 -table test.sqlite.db 'SELECT * FROM log_raw'
RUN cp /log2sqlite-grok.wasm /usr/local/bin/
RUN cp /log2parsed.wasm /usr/local/bin/

FROM scratch
COPY --link --from=demo /usr/local/bin/log2sqlite-grok.wasm /
COPY --link --from=demo /usr/local/bin/log2parsed.wasm /
