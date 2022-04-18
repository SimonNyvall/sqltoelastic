#!/usr/bin/env pwsh
Set-StrictMode -v latest
$ErrorActionPreference = "Stop"

function Main() {
    docker ps | grep -v "^CONTAINER" | awk '{print $1}' | xargs -r docker stop

    docker ps

    [string] $curdir = (Get-Location).Path
    [string] $bindmount = "$($curdir)/tests:/tests"

    [string] $containerMysql = $(docker ps | grep 'mysql' | awk '{print $1}')
    if ($containerMysql) {
        Log "Reusing existing mysql container: $containerMysql"
    }
    else {
        Log "Starting mysql:"
        docker run -d -p 3306:3306 -v $bindmount -e 'MYSQL_ROOT_PASSWORD=abcABC123' mymysql
        [string] $containerMysql = $(docker ps | grep 'mysql' | awk '{print $1}')
    }

    [string] $containerPostgres = $(docker ps | grep 'postgres' | awk '{print $1}')
    if ($containerPostgres) {
        Log "Reusing existing postgres container: $containerPostgres"
    }
    else {
        Log "Starting postgres:"
        docker run -d -p 5432:5432 -v $bindmount -e 'POSTGRES_PASSWORD=abcABC123' postgres
        [string] $containerPostgres = $(docker ps | grep 'postgres' | awk '{print $1}')
    }

    if ($(uname -m) -ne "arm64") {
        [string] $containerimage = 'mcr.microsoft.com/mssql/server'
    }
    else {
        [string] $containerimage = "mcr.microsoft.com/azure-sql-edge"
    }
    Log "Using container image: '$containerimage"
    [string] $containerSqlserver = $(docker ps | grep $containerimage | awk '{print $1}')
    if ($containerSqlserver) {
        Log "Reusing existing sqlserver container: $containerSqlserver"
    }
    else {
        Log "Starting sqlserver:"
        docker run -d -p 1433:1433 -v $bindmount -e 'ACCEPT_EULA=Y' -e 'SA_PASSWORD=abcABC123' $containerimage
        [string] $containerSqlserver = $(docker ps | grep $containerimage | awk '{print $1}')
    }

    [string] $containerElasticsearch = $(docker ps | grep 'elasticsearch' | awk '{print $1}')
    if ($containerElasticsearch) {
        Log "Reusing existing elasticsearch container: $containerElasticsearch"
    }
    else {
        Log "Starting elasticsearch:"
        docker run -d -p 9200:9200 -e discovery.type=single-node -e bootstrap.memory_lock=true -e 'ES_JAVA_OPTS=-Xms1024m -Xmx1024m' elasticsearch:7.17.1
        [string] $containerElasticsearch = $(docker ps | grep 'mcr.microsoft.com/mssql/server' | awk '{print $1}')
    }

    Log "Running containers:"
    docker ps

    Log "Running mysql script in $($containerMysql):"
    docker exec $containerMysql /tests/setupmysql.sh

    Log "Running postgres script in $($containerPostgres):"
    docker exec $containerPostgres /usr/bin/psql -U postgres -f /tests/testdataPostgres1.sql
    docker exec $containerPostgres /usr/bin/psql -U postgres -d testdb -f /tests/testdataPostgres2.sql

    Log "Running sqlserver script in $($containerSqlserver):"
    docker exec $containerSqlserver /tests/setupsqlserver.sh

    Log "Waiting for elasticsearch startup..."
    sleep 15

    Log "Importing mysql:"
    dotnet run --project src configMysql.json
    jq 'del(.took)' result.json > result_mysql.json
    diff result_mysql.json tests/expected_mysql.json
    if (!$?) {
        Log "Error: mysql."
    }

    Log "Importing postgres:"
    dotnet run --project src configPostgres.json
    jq 'del(.took)' result.json > result_postgres.json
    diff result_postgres.json tests/expected_postgres.json
    if (!$?) {
        Log "Error: postgres."
    }

    Log "Importing sqlserver:"
    dotnet run --project src configSqlserver.json
    jq 'del(.took)' result.json > result_sqlserver.json
    diff result_sqlserver.json tests/expected_sqlserver.json
    if (!$?) {
        Log "Error: sqlserver."
    }
}

function Log($message) {
    Write-Host $message -f Cyan
}

Main
