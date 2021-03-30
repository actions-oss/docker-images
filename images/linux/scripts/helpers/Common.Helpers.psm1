function Get-CommandResult {
    param (
        [Parameter(Mandatory = $true)]
        [string] $Command,
        [switch] $Multiline
    )
    # Bash trick to suppress and show error output because some commands write to stderr (for example, "python --version")
    $stdout = & bash -c "$Command 2>&1"
    $exitCode = $LASTEXITCODE
    return @{
        Output   = If ($Multiline -eq $true) { $stdout } else { [string]$stdout }
        ExitCode = $exitCode
    }
}

function Get-OSName {
    lsb_release -ds
}

function Get-KernelVersion {
    $kernelVersion = uname -r
    return "Linux kernel version: $kernelVersion"
}

function Test-IsUbuntu16 {
    return (lsb_release -rs) -eq "16.04"
}

function Test-IsUbuntu18 {
    return (lsb_release -rs) -eq "18.04"
}

function Test-IsUbuntu20 {
    return (lsb_release -rs) -eq "20.04"
}

function Get-ToolsetContent {
    $toolset = Join-Path $env:INSTALLER_SCRIPT_FOLDER "toolset.json"
    Get-Content $toolset -Raw | ConvertFrom-Json
}

function Get-ToolsetValue {
    param (
        [Parameter(Mandatory = $true)]
        [string] $KeyPath
    )

    $jsonNode = Get-ToolsetContent

    $pathParts = $KeyPath.Split(".")
    # try to walk through all arguments consequentially to resolve specific json node
    $pathParts | ForEach-Object {
        $jsonNode = $jsonNode.$_
    }
    return $jsonNode
}

function Get-AndroidPackages {
    $androidSDKManagerPath = "/usr/local/lib/android/sdk/tools/bin/sdkmanager"
    $androidPackages = & $androidSDKManagerPath --list --verbose
    return $androidPackages
}

function Get-EnvironmentVariable($variable) {
    return [System.Environment]::GetEnvironmentVariable($variable)
}

function Set-EnvironmentVariable($Variable, $Value) {
    return [System.Environment]::SetEnvironmentVariable($Variable, $Value)
}

function Join-EnvironmentVariable($Values) {
    return ($Values -join [System.IO.Path]::PathSeparator)
}

function Add-EnvironmentVariable($Variable, $Value) {
    ($Variable, $Value) -join '=' | sudo tee -a /etc/environment
}

function Update-EnvironmentFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$VariableName,
        [Parameter(Mandatory)]
        [String]$VariableValue
    )
    if ($Null -eq $VariableName) {
        return 1
    }
    Write-Debug $VariableName

    $EnvContent = [System.Collections.Generic.Dictionary[String, String]]::New()

    Get-Content -LiteralPath '/etc/environment' | ForEach-Object {
        Write-Debug $_
        $VarName, $VarValue = $_ -split '='
        $EnvContent.Add($VarName, $VarValue)
    }

    Write-Debug $EnvContent
    ${EnvContent}.${VariableName} = $VariableValue

    ($EnvContent.Keys, $EnvContent.Values) -join '=' | sudo tee /etc/environment

    return $LASTEXITCODE
}

function Edit-Environment {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$VariableName,
        [Parameter(Mandatory)]
        [String]$Value,
        [Parameter(Mandatory)]
        [ValidateSet('ReturnMerge', 'ReturnAppend', 'ReturnPrepend', 'Merge', 'Append', 'Prepend', 'Set', 'Replace', 'Add')]
        [String]$Action
    )
    
    if ($Action -notin @('Set', 'Replace', 'Add')) {
        $ExistingValue = Get-EnvironmentVariable -Variable $VariableName
    }

    switch ($Action) {
        { $_ -in @('ReturnMerge', 'ReturnAppend') } {
            return (Join-EnvironmentVariable ($ExistingValue, $Value))
        }

        { $_ -in @('ReturnPrepend') } {
            return (Join-EnvironmentVariable ($Value, $ExistingValue))
        }

        { $_ -in @('Merge', 'Append') } {
            $NewValue = (Join-EnvironmentVariable ($ExistingValue, $Value))
            break
        }

        { $_ -in @('Prepend') } {
            $NewValue = (Join-EnvironmentVariable ($Value, $ExistingValue))
            break
        }

        { $_ -in @('Set', 'Replace', 'Add') } {
            $NewValue = $Value
            break
        }

        Default {
            return
        }
    }

    return (Update-EnvironmentFile -VariableName $VariableName -VariableValue $NewValue)
}

function Update-Environment {
    $Env = Get-Content -LiteralPath /etc/environment
    $Env | ForEach-Object {
        $Name, $Value = $_ -split "="
        if ($Name -eq 'PATH') {
            Set-EnvironmentVariable -Name $Name -Value (Edit-Environment -VariableName PATH -Value $Value -Action ReturnMerge)
        } else {
            Set-EnvironmentVariable -Name $Name -Value $Value
        }
    }
}
