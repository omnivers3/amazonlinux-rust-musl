# AmazonLinux Rust MUSL Build Image

[Github Repository](github.com/omnivers3/amazon-rust-musl)

Extends the amazonlinux:latest image with the following:
- Uses the offically supported amazonlinux docker image
- Installs and configures the MUSL build target
- Installs and configures the OPENSSL 1.1.1
    - With ARG to override version