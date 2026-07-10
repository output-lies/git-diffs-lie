#!/bin/bash
## A clean, non-executable baseline shell file.
set -o errexit -o nounset -o pipefail
gcc -Wall -o hello src/hello.c
