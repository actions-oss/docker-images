#Requires -Version 7
#Requires -Modules Pester
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

Import-Module "${env:HELPER_SCRIPTS}/Common.Helpers.psm1" -DisableNameChecking
Import-Module "${env:HELPER_SCRIPTS}/Tests.Helpers.psm1" -DisableNameChecking

# Get modules content from toolset
$DotNetToolset = (Get-ToolsetContent).dotnet
$LatestDotNetPackages = $DotNetToolset.aptPackages
$Versions = $DotNetToolset.versions
$ThrottleLimit = [System.Environment]::ProcessorCount

$env:DOTNET_CLI_TELEMETRY_OPTOUT = $true

foreach ($Package in $latestDotNetPackages) {
    Write-Host "Determing if .NET Core (${Package}) is installed"
    if ((Get-CommandResult -Command "dpkg -S $Package").ExitCode -eq 0) {
        Write-Host ".NET Core (${Package}) is already installed"
    } else {
        Write-Host "Could not find .NET Core (${Package}), installing..."
        apt-get install $Package -y
    }
}

$SDKs = [System.Collections.Generic.List[string]]::New()
foreach ($Version in $versions) {
    $releaseUrl = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/${Version}/releases.json"
    $Releases = Invoke-RestMethod $ReleaseUrl
    $SDKs.Add($Releases.releases.sdk.version)
    $SDKs.Add($Releases.releases.sdks.version)
}

$SortedSDKs = $SDKs -split ' ' | Select-String -Pattern 'preview|rc|display' -NotMatch | Sort-Object -Unique

$SortedSDKs | ForEach-Object -Parallel {
    $SDKVersion = $_
    $BaseName = "dotnet-sdk-${SDKVersion}-linux-x64"
    $FileName = "${BaseName}.tar.gz"

    Write-Host "v${SDKVersion} | Retrieving DotNet"
    aria2c "https://dotnetcli.blob.core.windows.net/dotnet/Sdk/${SDKVersion}/${FileName}"

    $Destination = Join-Path $PWD "tmp-${BaseName}"
    Write-Output "v${SDKVersion} | Extracting ${FileName} to ${Destination}"
    New-Item -Path $Destination -ItemType Directory -Force | Out-Null
    tar -C $Destination -zxf $FileName
    foreach ($path in @("shared", "host", "sdk")) {
        rsync -qav --remove-source-files $Destination/$path/ /usr/share/dotnet/$path/
    }
    Remove-Item -LiteralPath $Destination -Recurse -Force
    Write-Host "v${SDKVersion} | DotNet installed"
} -ThrottleLimit $ThrottleLimit

<#
foreach ($SDKVersion in $sortedSDKs) {
    Write-Host "v${SDKVersion} | Validating install"
    @("console", "mstest", "xunit", "web", "mvc", "webapi") | ForEach-Object -Parallel {
        $SDKVersion = $using:SDKVersion
        $Sample = $_
        New-Item -Path $PWD -Name "${SDKVersion}_${Sample}" -ItemType Directory -Force
        try {
            Push-Location -LiteralPath "${SDKVersion}_${Sample}"
        } catch {
            throw "Failed to enter directory ${SDKVersion}_${Sample}"
        }
        dotnet new globaljson --sdk-version $SDKVersion
        dotnet new $Sample
        dotnet restore
        dotnet build
        try {
            Pop-Location
        } catch {
            throw "Failed to exit directory ${SDKVersion}_${Sample}"
        }
        Remove-Item -LiteralPath "${SDKVersion}_${Sample}" -Recurse -Force
    } -ThrottleLimit $ThrottleLimit
}
#>

Add-EnvironmentVariable -Variable 'DOTNET_SKIP_FIRST_TIME_EXPERIENCE' -Value 1
Add-EnvironmentVariable -Variable 'DOTNET_NOLOGO' -Value 1
Add-EnvironmentVariable -Variable 'DOTNET_MULTILEVEL_LOOKUP' -Value 0
#Edit-Environment -Variable 'PATH' -Value '/home/runner/.dotnet/tools' -Action 'Prepend'

'export PATH="$PATH:$HOME/.dotnet/tools"' | Tee-Object -FilePath '/etc/skel/.bashrc' -Append

Invoke-PesterTests -TestFile "DotnetSDK"
