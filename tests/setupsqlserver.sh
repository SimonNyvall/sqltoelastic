#!/bin/bash
echo 'Setting up sqlserver...'

cd
pwd
url='https://github.com/microsoft/go-sqlcmd/releases/download/v0.6.0/sqlcmd-v0.6.0-linux-arm64.tar.bz2'
filename=$(basename $url)
echo "Downloading: '$url' -> '$filename'"
curl -L $url -o $filename
tar -xvf $filename
ls -la

SQLCMDPASSWORD=abcABC123
export SQLCMDPASSWORD
./sqlcmd -U sa -i /tests/testdataSqlserver1.sql
./sqlcmd -U sa -i /tests/testdataSqlserver2.sql

echo 'Done!'
