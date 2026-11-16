#requires -Version 5.1
<#
.SYNOPSIS
    为 Windows 安装 Codex API 环境变量自动加载配置。
.DESCRIPTION
    读取 CODEX_ENV_CONFIG、CODEX_HOME/config.toml 或用户目录下的 .codex/config.toml。
    根据 model_provider 读取 base_url、experimental_bearer_token 或 env_key，
    设置 OPENAI_BASE_URL 和 OPENAI_API_KEY。配置不完整时跳过，不清空已有变量。
    默认保存到当前用户环境变量，并配置 Windows PowerShell 和 PowerShell 7 profile。
    安装后完全退出并重开 Codex；普通 PowerShell 会话会在启动时刷新配置。
    -NoProfile 会话只继承父进程环境；配置变更后需重新运行本脚本并重启 Codex。
    不改变系统执行策略；profile 自动加载仍受现有执行策略约束。
    不执行配置文件中的代码，不读取 auth.json，也不显示密钥。
.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-codex-env.ps1
.EXAMPLE
    .\setup-codex-env.ps1 -ConfigPath 'D:\Codex\config.toml'
.PARAMETER NoPersist
    只设置本进程环境，不保存到 Windows 用户环境变量。
.PARAMETER NoProfile
    不修改 PowerShell 启动文件。
#>
[CmdletBinding()]
param(
    [string] $InstallDir = $env:CODEX_ENV_INSTALL_DIR,
    [string] $StartupDir = $env:CODEX_ENV_STARTUP_DIR,
    [string] $ConfigPath = $env:CODEX_ENV_CONFIG,
    [switch] $NoPersist,
    [switch] $NoProfile,
    [switch] $Help
)

if ($Help) {
    Write-Output '用法：powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-codex-env.ps1'
    Write-Output '可选：-ConfigPath 路径、-InstallDir 路径、-StartupDir 路径、-NoPersist、-NoProfile。'
    Write-Output '安装后完全退出并重开 Codex。配置缺失时保留已有变量；CODEX_ENV_STRICT=1 启用诊断。'
    return
}

$ErrorActionPreference = 'Stop'
$runningOnWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
if (-not $runningOnWindows -and -not $NoPersist) {
    throw '此安装器用于 Windows；跨平台验证时必须使用 -NoPersist 和显式安装路径。'
}
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $localData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localData)) { throw '无法确定当前用户的应用数据目录。' }
    $InstallDir = Join-Path $localData 'codex-env'
}
$InstallDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($InstallDir)
$loaderPath = Join-Path $InstallDir 'env.ps1'
$utf8Bom = [Text.UTF8Encoding]::new($true)

$loaderSource = @'
#requires -Version 5.1
# 自动加载时缺少配置会静默跳过，已有环境变量保持不变。
# 手动诊断：& "$env:LOCALAPPDATA\codex-env\env.ps1" -Check
[CmdletBinding()]
param([switch] $Persist, [switch] $Check, [string] $ConfigPath)

$ErrorActionPreference = 'Stop'

function ConvertFrom-CodexTomlString {
    param([string] $RawValue)
    $text = $RawValue.Trim()
    if ($text.Length -lt 2 -or ($text[0] -ne [char]34 -and $text[0] -ne [char]39)) {
        throw [FormatException]::new('所需配置项必须是单行引号字符串。')
    }
    $quote = $text[0]
    $builder = [Text.StringBuilder]::new()
    for ($index = 1; $index -lt $text.Length; $index++) {
        $character = $text[$index]
        if ($character -eq $quote) {
            $remaining = $text.Substring($index + 1).Trim()
            if ($remaining.Length -gt 0 -and -not $remaining.StartsWith('#')) {
                throw [FormatException]::new('所需配置项不是支持的单行字符串。')
            }
            return $builder.ToString()
        }
        if ($quote -eq [char]34 -and $character -eq [char]92) {
            $index++
            if ($index -ge $text.Length) {
                throw [FormatException]::new('所需配置项的引号不完整。')
            }
            $character = $text[$index]
            if ($character -ne [char]92 -and $character -ne [char]34) {
                throw [FormatException]::new('所需配置项包含不支持的 TOML 转义。')
            }
        }
        [void] $builder.Append($character)
    }
    throw [FormatException]::new('所需配置项的引号不完整。')
}

function Read-CodexProviderEnvironment {
    param([string] $Path)
    if (-not [IO.File]::Exists($Path)) {
        throw [FormatException]::new('配置文件不存在或不可读。')
    }
    $activeProvider = 'openai'
    $openaiUrl = $null
    $sectionKind = 'root'
    $sectionName = $null
    $providers = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($rawLine in [IO.File]::ReadAllLines($Path)) {
        $line = $rawLine.Trim()
        if ($line.Length -eq 0 -or $line.StartsWith('#')) { continue }
        if ($line.StartsWith('[')) {
            $sectionKind = 'other'
            if ($line -cmatch '^\[\s*model_providers\s*\.\s*(.+?)\s*\]\s*(?:#.*)?$') {
                $rawName = $Matches[1].Trim()
                if ($rawName -cmatch '^[A-Za-z0-9_-]+$') { $sectionName = $rawName }
                elseif ($rawName[0] -eq [char]34 -or $rawName[0] -eq [char]39) {
                    $sectionName = ConvertFrom-CodexTomlString $rawName
                }
                else { continue }
                $sectionKind = 'provider'
                if (-not $providers.ContainsKey($sectionName)) {
                    $providers[$sectionName] = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
                }
            }
            continue
        }
        if ($line -cnotmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { continue }
        $field = $Matches[1]
        $rawValue = $Matches[2]
        if ($sectionKind -eq 'root') {
            if ($field -ceq 'model_provider') { $activeProvider = ConvertFrom-CodexTomlString $rawValue }
            elseif ($field -ceq 'openai_base_url') { $openaiUrl = $rawValue }
        }
        elseif ($sectionKind -eq 'provider' -and $field -cin @('base_url','env_key','experimental_bearer_token')) {
            $providers[$sectionName][$field] = $rawValue
        }
    }
    $provider = [Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    if ($providers.ContainsKey($activeProvider)) { $provider = $providers[$activeProvider] }
    if ($provider.ContainsKey('base_url')) {
        $baseUrl = ConvertFrom-CodexTomlString $provider['base_url']
    }
    elseif ($activeProvider -ceq 'openai') {
        if ($null -ne $openaiUrl) { $baseUrl = ConvertFrom-CodexTomlString $openaiUrl }
        elseif (-not [string]::IsNullOrEmpty($env:OPENAI_BASE_URL)) { $baseUrl = $env:OPENAI_BASE_URL }
        else { $baseUrl = 'https://api.openai.com/v1' }
    }
    else { throw [FormatException]::new('当前 provider 没有配置 base_url。') }

    if ($provider.ContainsKey('env_key')) {
        $variable = ConvertFrom-CodexTomlString $provider['env_key']
        if ($variable -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw [FormatException]::new('env_key 不是有效的环境变量名称。')
        }
        $apiKey = [Environment]::GetEnvironmentVariable($variable, 'Process')
    }
    elseif ($provider.ContainsKey('experimental_bearer_token')) {
        $apiKey = ConvertFrom-CodexTomlString $provider['experimental_bearer_token']
    }
    elseif ($activeProvider -ceq 'openai') { $apiKey = $env:OPENAI_API_KEY }
    else { throw [FormatException]::new('当前 provider 没有配置 experimental_bearer_token 或 env_key。') }

    if ([string]::IsNullOrWhiteSpace($baseUrl) -or [string]::IsNullOrWhiteSpace($apiKey)) {
        throw [FormatException]::new('地址或密钥为空，请检查配置及环境变量。')
    }
    if ($baseUrl -match '[\x00-\x1f\x7f]' -or $apiKey -match '[\x00-\x1f\x7f]') {
        throw [FormatException]::new('地址或密钥不能包含换行等控制字符。')
    }
    return @{ BaseUrl = $baseUrl; ApiKey = $apiKey }
}

try {
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) { $ConfigPath = $env:CODEX_ENV_CONFIG }
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $settingsFile = Join-Path $PSScriptRoot 'config-path.txt'
        if ([IO.File]::Exists($settingsFile)) { $ConfigPath = [IO.File]::ReadAllText($settingsFile).Trim() }
    }
    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $stateRoot = $env:CODEX_HOME
        if ([string]::IsNullOrWhiteSpace($stateRoot)) {
            $stateRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
        }
        $ConfigPath = Join-Path $stateRoot 'config.toml'
    }
    $settings = Read-CodexProviderEnvironment $ConfigPath
    if ($Persist) {
        if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
            throw [FormatException]::new('保存用户环境变量只支持 Windows。')
        }
        $previousUrl = [Environment]::GetEnvironmentVariable('OPENAI_BASE_URL', 'User')
        $previousKey = [Environment]::GetEnvironmentVariable('OPENAI_API_KEY', 'User')
        try {
            if ($previousUrl -cne $settings.BaseUrl) {
                [Environment]::SetEnvironmentVariable('OPENAI_BASE_URL', $settings.BaseUrl, 'User')
            }
            if ($previousKey -cne $settings.ApiKey) {
                [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $settings.ApiKey, 'User')
            }
        }
        catch {
            try {
                [Environment]::SetEnvironmentVariable('OPENAI_BASE_URL', $previousUrl, 'User')
                [Environment]::SetEnvironmentVariable('OPENAI_API_KEY', $previousKey, 'User')
            } catch { }
            throw [FormatException]::new('无法保存当前用户环境变量，请检查用户环境变量的写入权限。')
        }
    }
    $env:OPENAI_BASE_URL = $settings.BaseUrl
    $env:OPENAI_API_KEY = $settings.ApiKey
    if ($Check) { Write-Output 'codex-env: 配置完整，环境变量已加载（不显示密钥）。' }
}
catch {
    if ($Check -or $env:CODEX_ENV_STRICT -eq '1') {
        $message = '配置读取失败，请检查文件权限和格式。'
        if ($_.Exception -is [FormatException]) { $message = $_.Exception.Message }
        throw [InvalidOperationException]::new(('codex-env: ' + $message))
    }
    # 自动加载失败不抛出错误，也不修改或清空已有环境变量。
}
'@

# 在写文件之前计算所有 profile 内容，避免不完整区块造成部分更新。
# 安装命令的一次性 Bypass 不代表新终端允许 profile；不修改执行策略。
if ($runningOnWindows -and -not $NoProfile) {
    $startupPolicy = 'Restricted'
    $policyList = @(Get-ExecutionPolicy -List)
    foreach ($scope in @('MachinePolicy','UserPolicy','CurrentUser','LocalMachine')) {
        $entry = $policyList | Where-Object { [string] $_.Scope -eq $scope } | Select-Object -First 1
        if ($null -ne $entry -and [string] $entry.ExecutionPolicy -ne 'Undefined') {
            $startupPolicy = [string] $entry.ExecutionPolicy
            break
        }
    }
    if ($startupPolicy -in @('Restricted','AllSigned')) {
        $NoProfile = $true
        Write-Output ('当前执行策略为 ' + $startupPolicy + '，跳过 profile 修改；使用用户环境变量供新进程继承。')
    }
}
$profilePaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
if (-not $NoProfile) {
    $documents = $StartupDir
    if ([string]::IsNullOrWhiteSpace($documents)) {
        if (-not $runningOnWindows) { throw '跨平台验证请显式指定 -StartupDir。' }
        $documents = [Environment]::GetFolderPath('MyDocuments')
        if ([string]::IsNullOrWhiteSpace($documents)) { throw '无法确定当前用户的文档目录。' }
        [void] $profilePaths.Add($PROFILE.CurrentUserAllHosts)
    }
    [void] $profilePaths.Add((Join-Path (Join-Path $documents 'WindowsPowerShell') 'profile.ps1'))
    [void] $profilePaths.Add((Join-Path (Join-Path $documents 'PowerShell') 'profile.ps1'))
}

$escapedLoader = $loaderPath.Replace("'", "''")
$persistArgument = ''
if (-not $NoPersist) { $persistArgument = ' -Persist' }
$profileBlock = "# >>> codex-env >>>`r`nif (Test-Path -LiteralPath '$escapedLoader' -PathType Leaf) {`r`n    & '$escapedLoader'$persistArgument`r`n}`r`n# <<< codex-env <<<`r`n"
$updates = @()
foreach ($path in $profilePaths) {
    $original = ''
    if ([IO.File]::Exists($path)) {
        $reader = [IO.StreamReader]::new($path, [Text.UTF8Encoding]::new($false, $true), $true)
        try { $original = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    $inside = $false
    $keptLines = [Collections.Generic.List[string]]::new()
    foreach ($line in [regex]::Split($original, '\r\n|\n|\r')) {
        if ($line -ceq '# >>> codex-env >>>') {
            if ($inside) { throw '启动文件中存在嵌套的 codex-env 配置区块。' }
            $inside = $true
        }
        elseif ($line -ceq '# <<< codex-env <<<') {
            if (-not $inside) { throw '启动文件中存在不完整的 codex-env 配置区块。' }
            $inside = $false
        }
        elseif (-not $inside) { $keptLines.Add($line) }
    }
    if ($inside) { throw '启动文件中存在不完整的 codex-env 配置区块。' }
    $kept = [string]::Join("`r`n", $keptLines).TrimEnd([char]13, [char]10)
    if ($kept.Length -gt 0) { $kept += "`r`n" }
    $updated = $kept + $profileBlock
    if ($original -cne $updated) { $updates += @{ Path = $path; Content = $updated } }
}

[void] [IO.Directory]::CreateDirectory($InstallDir)
if ([IO.File]::Exists($loaderPath) -and [IO.File]::ReadAllText($loaderPath) -cne $loaderSource) {
    [IO.File]::Copy($loaderPath, ($loaderPath + '.backup-' + [Guid]::NewGuid().ToString('N')))
}
[IO.File]::WriteAllText($loaderPath, $loaderSource, $utf8Bom)
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $absoluteConfig = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigPath)
    [IO.File]::WriteAllText((Join-Path $InstallDir 'config-path.txt'), $absoluteConfig, $utf8Bom)
}
foreach ($update in $updates) {
    $path = $update.Path
    [void] [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    if ([IO.File]::Exists($path)) {
        [IO.File]::Copy($path, ($path + '.codex-env-backup-' + [Guid]::NewGuid().ToString('N')))
    }
    [IO.File]::WriteAllText($path, $update.Content, $utf8Bom)
    Write-Output ('已配置：' + $path)
}

& $loaderPath -Persist:(-not $NoPersist)
Write-Output '安装完成。配置完整时设置 OPENAI_BASE_URL 和 OPENAI_API_KEY；配置缺失时保留已有值。'
if (-not $NoPersist) { Write-Output '已启用用户环境变量保存。请完全退出并重开 Codex、终端及其启动器。' }
Write-Output '默认不改变执行策略。普通 PowerShell 自动刷新需要现有策略允许 profile 和本地脚本运行。'
Write-Output ('手动诊断：& ''' + $escapedLoader + ''' -Check')
