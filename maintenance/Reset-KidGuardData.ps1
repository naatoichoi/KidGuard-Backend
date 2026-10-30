param(
    [string]$BackendRoot = 'D:\LTDiDong\KT\phamngocanh\phamngocanh',
    [string]$ExpectedDatabaseName,
    [switch]$Reset
)
$ErrorActionPreference = 'Stop'
$connectionText = $null
$configFiles = @((Join-Path $BackendRoot 'appsettings.json'), (Join-Path $BackendRoot 'appsettings.Development.json'))
[xml]$project = Get-Content -Raw -LiteralPath (Join-Path $BackendRoot 'phamngocanh.csproj')
$secretId = @($project.Project.PropertyGroup.UserSecretsId) | Where-Object { $_ } | Select-Object -First 1
if ($secretId) { $configFiles += Join-Path $env:APPDATA ('Microsoft/UserSecrets/' + $secretId + '/secrets.json') }
foreach ($file in $configFiles) {
    if (Test-Path -LiteralPath $file) {
        $config = Get-Content -Raw -Encoding utf8 -LiteralPath $file | ConvertFrom-Json
        $candidate = $config.'ConnectionStrings:DefaultConnection'
        if (!$candidate) { $candidate = $config.ConnectionStrings.DefaultConnection }
        if ($candidate) { $connectionText = [string]$candidate }
    }
}
if ($env:ConnectionStrings__DefaultConnection) { $connectionText = $env:ConnectionStrings__DefaultConnection }
if (!$connectionText) { throw 'No backend database connection configured.' }
$builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($connectionText)
$database = $builder.InitialCatalog
if (!$database -or $database -in @('master', 'model', 'msdb', 'tempdb') -or $database -notmatch '(?i)kidguard|phamngocanh') {
    throw 'Refusing to operate outside the named KidGuard project database.'
}
$allowedTables = @('AppUsages', 'AspNetRoleClaims', 'AspNetRoles', 'AspNetUserClaims', 'AspNetUserLogins',
    'AspNetUserRoles', 'AspNetUsers', 'AspNetUserTokens', 'Children', 'DailyScreenTimes', 'DeviceSyncLogs',
    'Devices', 'Locations', 'Notifications', 'OtpCodes', 'PairingCodes', 'ParentChildren', 'ScreenTimeLimits',
    'TimeExtensions', 'TimeRequests')
$connection = New-Object System.Data.SqlClient.SqlConnection($connectionText)
$connection.Open()
try {
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 120
    $command.CommandText = "SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('dbo') AND is_ms_shipped = 0 ORDER BY name"
    $reader = $command.ExecuteReader()
    $tables = @()
    while ($reader.Read()) { $tables += [string]$reader[0] }
    $reader.Close()
    foreach ($required in @('AspNetUsers', 'Children', 'Devices', 'Locations', 'ScreenTimeLimits')) {
        if ($required -notin $tables) { throw 'Configured database does not match the KidGuard schema.' }
    }
    $tables = @($tables | Where-Object { $_ -in $allowedTables })
    $command.CommandText = 'SELECT COUNT_BIG(*) FROM dbo.AspNetUsers'
    $users = $command.ExecuteScalar()
    if (!$Reset) {
        [pscustomobject]@{ Database = $database; Accounts = $users; AppTables = $tables.Count }
        return
    }
    if ($ExpectedDatabaseName -cne $database) { throw 'ExpectedDatabaseName must match the inspected database exactly.' }
    $command.CommandText = "SELECT CONVERT(nvarchar(4000), SERVERPROPERTY('InstanceDefaultBackupPath'))"
    $backupRoot = [string]$command.ExecuteScalar()
    if (!$backupRoot) { throw 'No SQL Server backup path; no data has been deleted.' }
    $backupName = ($database -replace '[^a-zA-Z0-9_.-]', '_') + '-before-reset-' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8) + '.bak'
    $backupPath = $backupRoot.TrimEnd('\', '/') + '\' + $backupName
    $quotedDatabase = '[' + $database.Replace(']', ']]') + ']'
    $command.CommandText = "BACKUP DATABASE $quotedDatabase TO DISK = @backupPath WITH COPY_ONLY, CHECKSUM, INIT"
    $null = $command.Parameters.Add('@backupPath', [System.Data.SqlDbType]::NVarChar, 4000)
    $command.Parameters['@backupPath'].Value = $backupPath
    $null = $command.ExecuteNonQuery()
    $command.CommandText = 'RESTORE VERIFYONLY FROM DISK = @backupPath WITH CHECKSUM'
    $null = $command.ExecuteNonQuery()
    $command.Parameters.Clear()

    $transaction = $connection.BeginTransaction()
    $command.Transaction = $transaction
    try {
        foreach ($table in $tables) {
            $command.CommandText = "ALTER TABLE [dbo].[$table] NOCHECK CONSTRAINT ALL"
            $null = $command.ExecuteNonQuery()
        }
        foreach ($table in $tables) {
            $command.CommandText = "DELETE FROM [dbo].[$table]"
            $null = $command.ExecuteNonQuery()
        }
        foreach ($table in $tables) {
            $command.CommandText = "ALTER TABLE [dbo].[$table] WITH CHECK CHECK CONSTRAINT ALL"
            $null = $command.ExecuteNonQuery()
        }
        $transaction.Commit()
    } catch { $transaction.Rollback(); throw }
    $command.Transaction = $null
    $command.CommandText = 'SELECT COUNT_BIG(*) FROM dbo.AspNetUsers'
    $remaining = $command.ExecuteScalar()
    $localBackup = $null
    try {
        $backupFolder = Join-Path (Split-Path -Parent $PSScriptRoot) 'build/backups'
        New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null
        $localBackup = Join-Path $backupFolder $backupName
        Copy-Item -LiteralPath $backupPath -Destination $localBackup
    } catch { $localBackup = $null }
    [pscustomobject]@{ Database = $database; RemainingAccounts = $remaining; ClearedTables = $tables.Count; ServerBackup = $backupPath; LocalBackup = $localBackup }
} finally { $connection.Dispose() }
