#!/bin/sh

nix build dotfiles#msbuild-ls.passthru.fetch-deps
chmod +x ./result
./result "$(pwd)/deps.json"
rm ./result
