# CaRMa

[![Circle CI](https://circleci.com/gh/f-me/carma.svg?style=svg&circle-token=ed097e1dbbde9591b7b2bec9ce252ddc840deb54)](https://circleci.com/gh/f-me/carma)

## Building instructions

On macOS with `openssl` installed via Homebrew, build with

    stack build --extra-include-dirs=/usr/local/opt/openssl/include/ --extra-include-dirs=/usr/local/opt/icu4c/include/ --extra-lib-dirs=/usr/local/opt/openssl/lib/ --extra-lib-dirs=/usr/local/opt/icu4c/lib/
