#!/bin/bash
set -e
cd "$(dirname "$0")"
./build-app.sh
printf '\nГотово. Нажмите Enter, чтобы закрыть окно...\n'
read -r
