FROM rustlang/rust:nightly as builder

RUN cargo install cargo-fuzz

ADD . /src
WORKDIR /src

RUN rm -f rust-toolchain rust-toolchain.toml && \
    echo building instrumented harnesses && \
    bash -c "pushd serde_dhall/fuzz && cargo fuzz build && popd" && \
    mv serde_dhall/fuzz/target/x86_64-unknown-linux-gnu/release/parse_dhall /parse_dhall && \
    echo done

RUN export RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1" && \
    bash -c "pushd serde_dhall/fuzz && cargo build --release && popd" && \
    mv serde_dhall/fuzz/target/release/parse_dhall /parse_dhall_no_inst

FROM rustlang/rust:nightly
COPY --from=builder /parse_dhall /parse_dhall_no_inst /
