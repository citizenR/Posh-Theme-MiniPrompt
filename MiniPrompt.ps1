
### Defaults

$global:ThemeSettings = New-Object -TypeName PSObject -Property @{
    CurrentUser          = [System.Environment]::UserName
    CurrentHostname      = [System.Environment]::MachineName
    ErrorCount           = 0

    PromptSymbols        = @{
        StartSymbol                    = ' '
        TruncatedFolderSymbol          = '..'
        PromptIndicator                = [char]::ConvertFromUtf32(0x25B6)
        FailedCommandSymbol            = [char]::ConvertFromUtf32(0x2A2F)
        ElevatedSymbol                 = [char]::ConvertFromUtf32(0x26A1)
        SegmentForwardSymbol           = [char]::ConvertFromUtf32(0xE0B0)
        SegmentBackwardSymbol          = [char]::ConvertFromUtf32(0x26A1)
        SegmentSeparatorForwardSymbol  = [char]::ConvertFromUtf32(0x26A1)
        SegmentSeparatorBackwardSymbol = [char]::ConvertFromUtf32(0x26A1)
        PathSeparator                  = [System.IO.Path]::DirectorySeparatorChar
        VirtualEnvSymbol               = [char]::ConvertFromUtf32(0xE606)
        HomeSymbol                     = '~'
        RootSymbol                     = '#'
        UNCSymbol                      = '§'
    }
    Colors               = @{
        GitDefaultColor                         = [ConsoleColor]::DarkGreen
        GitLocalChangesColor                    = [ConsoleColor]::DarkYellow
        GitNoLocalChangesAndAheadColor          = [ConsoleColor]::DarkMagenta
        GitNoLocalChangesAndBehindColor         = [ConsoleColor]::DarkRed
        GitNoLocalChangesAndAheadAndBehindColor = [ConsoleColor]::DarkRed
        PromptForegroundColor                   = [ConsoleColor]::White
        PromptHighlightColor                    = [ConsoleColor]::DarkBlue
        DriveForegroundColor                    = [ConsoleColor]::DarkBlue
        PromptBackgroundColor                   = [ConsoleColor]::DarkBlue
        PromptSymbolColor                       = [ConsoleColor]::White
        SessionInfoBackgroundColor              = [ConsoleColor]::Black
        SessionInfoForegroundColor              = [ConsoleColor]::White
        CommandFailedIconForegroundColor        = [ConsoleColor]::DarkRed
        AdminIconForegroundColor                = [ConsoleColor]::DarkYellow
        WithBackgroundColor                     = [ConsoleColor]::DarkRed
        WithForegroundColor                     = [ConsoleColor]::White
        VirtualEnvForegroundColor               = [ConsoleColor]::White
        VirtualEnvBackgroundColor               = [ConsoleColor]::Red
    }
    Options              = @{
        ConsoleTitle  = $true
        OriginSymbols = $false
    }
}

# PSColor default settings
$global:PSColor = @{
    File    = @{
        Default    = @{ Color = 'White' }
        Directory  = @{ Color = 'DarkBlue' }
        Hidden     = @{ Color = 'Gray'; Pattern = '^\.' }
        Code       = @{ Color = 'Magenta'; Pattern = '\.(java|c|cpp|cs|js|css|html)$' }
        Executable = @{ Color = 'Red'; Pattern = '\.(exe|bat|cmd|py|pl|ps1|psm1|vbs|rb|reg)$' }
        Text       = @{ Color = 'White'; Pattern = '\.(txt|cfg|conf|ini|csv|log|config|xml|yml|md|markdown)$' }
        Compressed = @{ Color = 'DarkGreen'; Pattern = '\.(zip|tar|gz|rar|jar|war)$' }
    }
    Service = @{
        Default = @{ Color = 'White' }
        Running = @{ Color = 'DarkGreen' }
        Stopped = @{ Color = 'DarkYellow' }
    }
    Match   = @{
        Default    = @{ Color = 'White' }
        Path       = @{ Color = 'Cyan' }
        LineNumber = @{ Color = 'DarkGreen' }
        Line       = @{ Color = 'White' }
    }
}


### Prompt Helper
<#
.SYNOPSIS
    Defines whether or not the current terminal supports ANSI characters
.DESCRIPTION
    Logic taken from posh-git that sets the $GitPromptSettings.AnsiConsole bool:
    [bool]$AnsiConsole = $Host.UI.SupportsVirtualTerminal -or ($Env:ConEmuANSI -eq "ON")
#>
function Test-IsVanillaWindow {
    $hasAnsiSupport = (Test-AnsiTerminal) -or ($Env:ConEmuANSI -eq "ON") -or ($env:PROMPT) -or ($env:TERM_PROGRAM -eq "Hyper") -or ($env:TERM_PROGRAM -eq "vscode")
    return !$hasAnsiSupport
}

function Test-AnsiTerminal {
    return $Host.UI.SupportsVirtualTerminal
}

function Test-PsCore {
    return $PSVersionTable.PSVersion.Major -gt 5
}

function Test-Windows {
    $PSVersionTable.Platform -ne 'Unix'
}

function Get-Home {
    # On Unix systems, $HOME comes with a trailing slash, unlike the Windows variant
    return $HOME.TrimEnd('/', '\')
}

function Test-Administrator {
    if ($PSVersionTable.Platform -eq 'Unix') {
        return (whoami) -eq 'root'
    }
    elseif ($PSVersionTable.Platform -eq 'Windows') {
        return $false #TO-DO: find out how to distinguish this one
    }
    else {
        return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    }
}

function Get-ComputerName {
    if (Test-PsCore -And -Not Test-Windows) {
        if ($env:COMPUTERNAME) {
            return $env:COMPUTERNAME
        }
        if ($env:NAME) {
            return $env:NAME
        }
        return (uname -n)
    }
    return $env:COMPUTERNAME
}

function Get-Provider {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PathInfo]
        $dir
    )

    return $dir.Provider.Name
}

function Get-FormattedRootLocation {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PathInfo]
        $dir
    )

    $provider = Get-Provider -dir $dir

    if ($provider -eq 'FileSystem') {
        $homedir = Get-Home
        if ($dir.Path.StartsWith($homedir)) {
            return $sl.PromptSymbols.HomeSymbol
        }
        if ($dir.Path.StartsWith('Microsoft.PowerShell.Core')) {
            return $sl.PromptSymbols.UNCSymbol
        }
        return ''
    }
    else {
        return $dir.Drive.Name
    }
}

function Get-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PathInfo]
        $dir
    )

    if ($dir.path -eq "$($dir.Drive.Name):\") {
        return "$($dir.Drive.Name):"
    }
    $path = $dir.path.Replace((Get-Home), $sl.PromptSymbols.HomeSymbol).Replace('\', $sl.PromptSymbols.PathSeparator)
    return $path
}

function Get-OSPathSeparator {
    return [System.IO.Path]::DirectorySeparatorChar
}

function Get-ShortPath {
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PathInfo]
        $dir
    )

    $provider = Get-Provider -dir $dir

    if ($provider -eq 'FileSystem') {
        # on UNIX systems, a trailing slash can be present, yet when calling $HOME there isn't one
        $path = $dir.Path.TrimEnd((Get-OSPathSeparator))
        # list known paths and their substitutes
        $knownPaths = (Get-Home), 'Microsoft.PowerShell.Core\FileSystem::'
        $result = @()
        while ($path -And -Not ($knownPaths.Contains($path))) {
            $folder = $path.Split((Get-OSPathSeparator))[-1]
            if (($result.length -eq 0) -Or -Not ($path.Contains((Get-OSPathSeparator)))) {
                $result = , $folder + $result
            }
            else {
                $result = , $sl.PromptSymbols.TruncatedFolderSymbol + $result
            }
            # remove the last element
            $path = $path.TrimEnd($folder).TrimEnd((Get-OSPathSeparator))
        }
        $shortPath = $result -join $sl.PromptSymbols.PathSeparator
        $rootLocation = (Get-FormattedRootLocation -dir $dir)
        if ($rootLocation -and $shortPath) {
            return "$rootLocation$($sl.PromptSymbols.PathSeparator)$shortPath"
        }
        if ($rootLocation) {
            return $rootLocation
        }
        return $shortPath
    }
    else {
        return $dir.path.Replace((Get-FormattedRootLocation -dir $dir), '')
    }
}
function Test-VirtualEnv {
    if ($env:VIRTUAL_ENV) {
        return $true
    }
    if ($Env:CONDA_PROMPT_MODIFIER) {
        return $true
    }
    return $false
}

function Get-VirtualEnvName {
    if ($env:VIRTUAL_ENV) {
        if ($PSVersionTable.Platform -eq 'Unix') {
            $virtualEnvName = ($env:VIRTUAL_ENV -split '/')[-1]
        } elseif ($PSVersionTable.Platform -eq 'Win32NT' -or $PSEdition -eq 'Desktop') {
            $virtualEnvName = ($env:VIRTUAL_ENV -split '\\')[-1]
        } else {
            $virtualEnvName = $env:VIRTUAL_ENV
        }
        return $virtualEnvName.Trim('[\/]')
    }
    elseif ($Env:CONDA_PROMPT_MODIFIER) {
        [regex]::Match($Env:CONDA_PROMPT_MODIFIER, "^\((.*)\)").Captures.Groups[1].Value;
    }
}

function Test-NotDefaultUser($user) {
    return $null -eq $DefaultUser -or $user -ne $DefaultUser
}

function Set-CursorForRightBlockWrite {
    param(
        [int]
        $textLength
    )

    $rawUI = $Host.UI.RawUI
    $width = $rawUI.BufferSize.Width
    $space = $width - $textLength
    Write-Prompt "$escapeChar[$($space)G"
}

function Reset-CursorPosition {
    $postion = $host.UI.RawUI.CursorPosition
    $postion.X = 0
    $host.UI.RawUI.CursorPosition = $postion
}

function Set-CursorUp {
    param(
        [int]
        $lines
    )
    return "$escapeChar[$($lines)A"
}

function Set-Newline {
    return Write-Prompt "`n"
}

$escapeChar = [char]27
$sl = $global:ThemeSettings #local settings


### Theme

function Write-Theme {

    param(
        [bool]
        $lastCommandFailed,
        [string]
        $with
    )

    $lastColor = $sl.Colors.PromptBackgroundColor
    $user = [System.Environment]::UserName
    $userSymbol = " λ "
    $adminSymbol = " # "

    #check the last command state and indicate if failed
    #check for elevated prompt
    if(Test-Administrator){
        if ($lastCommandFailed) {
            $prompt = Write-Prompt -Object $adminSymbol -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.CommandFailedIconForegroundColor
        } else {
            $prompt = Write-Prompt -Object $adminSymbol -ForegroundColor $sl.Colors.PromptWarnColorD -BackgroundColor $sl.Colors.PromptWarnColorY
        }
    }else{
        if ($lastCommandFailed) {
            $prompt = Write-Prompt -Object $userSymbol -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.CommandFailedIconForegroundColor
        } else {
            $prompt = Write-Prompt -Object $userSymbol -ForegroundColor $sl.Colors.SessionInfoForegroundColor -BackgroundColor $sl.Colors.SessionInfoBackgroundColor
        }
    }


    if (Test-VirtualEnv) {
        $prompt += Write-Prompt -Object " (venv) $(Get-VirtualEnvName) " -ForegroundColor $sl.Colors.VirtualEnvForegroundColor -BackgroundColor $sl.Colors.VirtualEnvBackgroundColor
    }

    # Writes the drive portion
    $path = ' ' + (Split-Path -leaf -path (Get-Location)) + ' '
    $prompt += Write-Prompt -Object $path -ForegroundColor $sl.Colors.PromptForegroundColor -BackgroundColor $sl.Colors.PromptBackgroundColor
    

    if ($with) {
        $prompt += Write-Prompt -Object " $($with.ToUpper()) " -BackgroundColor $sl.Colors.WithBackgroundColor -ForegroundColor $sl.Colors.WithForegroundColor
        $lastColor = $sl.Colors.WithBackgroundColor
    }

    # Writes the postfix to the prompt
    $prompt += ' '
    $prompt
}

$sl = $global:ThemeSettings #local settings
$sl.PromptSymbols.SegmentForwardSymbol = ""
$sl.Colors.SessionInfoBackgroundColor = [ConsoleColor]::DarkGray
$sl.Colors.PromptForegroundColor = [ConsoleColor]::White
$sl.Colors.PromptSymbolColor = [ConsoleColor]::White
$sl.Colors.PromptWarnColorY = [ConsoleColor]::Yellow
$sl.Colors.PromptWarnColorD = [ConsoleColor]::DarkGray
$sl.Colors.PromptHighlightColor = [ConsoleColor]::DarkBlue
$sl.Colors.WithForegroundColor = [ConsoleColor]::White
$sl.Colors.WithBackgroundColor = [ConsoleColor]::DarkRed
$sl.Colors.VirtualEnvBackgroundColor = [System.ConsoleColor]::Red
$sl.Colors.VirtualEnvForegroundColor = [System.ConsoleColor]::White


### Set-Prompt

<#
        .SYNOPSIS
        Generates the prompt before each line in the console
#>
function Set-Prompt {
    # Import-Module $sl.CurrentThemeLocation -Force

    [ScriptBlock]$Prompt = {
        $lastCommandFailed = ($global:error.Count -gt $sl.ErrorCount) -or -not $?
        $sl.ErrorCount = $global:error.Count

        #Start the vanilla posh-git when in a vanilla window, else: go nuts
        if(Test-IsVanillaWindow) {
            Write-Host -Object ($pwd.ProviderPath) -NoNewline
        }

        Reset-CursorPosition
        $prompt = (Write-Theme -lastCommandFailed $lastCommandFailed)

        if($sl.Options.ConsoleTitle) {
            $location = Get-Location
            $folder = (Get-ChildItem | Select-Object -First 1).Parent.BaseName
            $prompt += "$([char]27)]2;$($folder)$([char]7)"
            if ($location.Provider.Name -eq "FileSystem") {
                $prompt += "$([char]27)]9;9;`"$($location.Path)`"$([char]7)"
            }
        }

        $prompt
    }

    Set-Item -Path Function:prompt -Value $Prompt -Force
}

function global:Write-WithPrompt() {
    param(
        [string]
        $command
    )

    $lastCommandFailed = $global:error.Count -gt $sl.ErrorCount
    $sl.ErrorCount = $global:error.Count

    if(Test-IsVanillaWindow) {
        Write-ClassicPrompt -command $command
        return
    }

    Write-Theme -lastCommandFailed $lastCommandFailed -with $command
}

### Setup Theme

Set-Prompt
