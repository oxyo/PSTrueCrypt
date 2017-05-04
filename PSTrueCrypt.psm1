#.ExternalHelp PSTrueCrypt-help.xml
function Mount-TrueCrypt
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $False)]
        [array]$KeyfilePath,

        [Parameter(Mandatory = $False)]
        [System.Security.SecureString]$Password
    )
    
    # TODO: need a better way to check for a subkey.  all keys may have been deleted but PSTrueCrypt still exists
    try 
    {
        $Settings = Get-PSTrueCryptContainer -Name $Name
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        Write-Error "At least one subkey of HKCU:\SOFTWARE\PSTrueCrypt is required.  Use New-PSTrueCryptContainer to add a subkey." -ErrorAction Stop
    }

    # construct arguments for expression and insert token in for password...
    [string]$Expression = Get-TrueCryptMountParams  -TrueCryptContainerPath $Settings.TrueCryptContainerPath -PreferredMountDrive $Settings.PreferredMountDrive -Product $Settings.Product -KeyfilePath $KeyfilePath -Timestamp $Settings.Timestamp

    # if no password was given, then we need to start the process for of prompting for one...
    if ([string]::IsNullOrEmpty($Password) -eq $True)
    {
        $WasConsolePromptingPrior
        # check to see if session is in admin mode for console prompting...
        if (Test-IsAdmin -eq $True)
        {
            $WasConsolePromptingPrior = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" | Select-Object -ExpandProperty ConsolePrompting

            Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name ConsolePrompting -Value $True
        }

        [securestring]$Password = Read-Host -Prompt "Enter password" -AsSecureString
    }

    # this method of handling password securely has been mentioned at the following links:
    # https://msdn.microsoft.com/en-us/library/system.security.securestring(v=vs.110).aspx
    # https://msdn.microsoft.com/en-us/library/system.runtime.interopservices.marshal.securestringtobstr(v=vs.110).aspx
    # https://msdn.microsoft.com/en-us/library/system.intptr(v=vs.110).aspx
    # https://msdn.microsoft.com/en-us/library/ewyktcaa(v=vs.110).aspx
    try
    {
        # Create IntPassword and dispose $Password...

        [System.IntPtr]$IntPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
    }
    catch [System.NotSupportedException]
    {
        # The current computer is not running Windows 2000 Service Pack 3 or later.
        Write-Error "The current computer is not running Windows 2000 Service Pack 3 or later."
    }
    catch [System.OutOfMemoryException]
    {
        # OutOfMemoryException
        Write-Error "Not enough memory for PSTrueCrypt to continue."
    }
    finally
    {
        $Password.Dispose()
    }

    try
    {
        # Execute Expression
        Invoke-Expression ($Expression -f [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($IntPassword))
    }
    catch [System.Exception]
    {
        Write-Error "An unkown issue occurred when TrueCrypt was executed.  Are keyfile(s) needed for this container?"
    }
    finally
    {
    # TODO: this is crashing CLS.  Is this to be called when dismount is done?  Perhaps TrueCrypt is 
    # holding on to this pointer while container is open.
    # [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemAnsi($IntPassword)
    }

    # if console prompting was set to false prior to this module, then set it back to false... 
    if ($WasConsolePromptingPrior -eq $False)
    {
        Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds" -Name ConsolePrompting -Value $False
    }

    if($KeyfilePath -ne $null)
    {
        Edit-HistoryFile -KeyfilePath $KeyfilePath
    }
}


#.ExternalHelp PSTrueCrypt-help.xml
function Dismount-TrueCrypt
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $False, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [switch]$ForceAll
    )

    # is Dismount-TrueCrypt has been invoked with the -Force flag, then it will have a value of true..
    if ($ForceAll -eq $False)
    {
        $Settings = Get-PSTrueCryptContainer -Name $Name
        
        # construct arguments and execute expression...
        [string]$Expression = Get-TrueCryptDismountParams -Drive $Settings.PreferredMountDrive -Product $Settings.Product

        Invoke-Expression $Expression
    }
    else
    {
        Invoke-DismountAll -Product TrueCrypt
        
        Invoke-DismountAll -Product VeraCrypt
    }
}


#.ExternalHelp PSTrueCrypt-help.xml
function Dismount-TrueCryptForceAll
{
    Dismount-TrueCrypt -ForceAll
}


#.ExternalHelp PSTrueCrypt-help.xml
function New-PSTrueCryptContainer
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Location,

        [Parameter(Mandatory = $True, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$MountLetter,

        [Parameter(Mandatory = $True, Position = 4)]
        [ValidateSet("TrueCrypt", "VeraCrypt")]
        [string]$Product,

        [switch]$Timestamp
    )

    $AccessRule = New-Object System.Security.AccessControl.RegistryAccessRule (
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name, "FullControl",
        [System.Security.AccessControl.InheritanceFlags]"ObjectInherit,ContainerInherit",
        [System.Security.AccessControl.PropagationFlags]"None",
        [System.Security.AccessControl.AccessControlType]"Allow")

    [System.String]$SubKeyName = New-Guid

    try
    {
        $Decision = Get-Confirmation -Message "New-PSTrueCryptContainer will add a new subkey in the following of your registry: HKCU:\SOFTWARE\PSTrueCrypt"

        if ($Decision -eq $True) 
        {
            $SubKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("SOFTWARE\PSTrueCrypt\$SubKeyName",
                    [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree)
        }
        else
        {
             Write-Warning "New-PSTrueCryptContainer operation has been cancelled."
        }
    }
    catch [System.UnauthorizedAccessException]
    {
        # TODO: append to this message of options for a solution.  solution will be determined if the user is in an elevated CLS.
        Write-Error "'UnauthorizedAccessException' has been thrown which prevents PSTrueCrypt from accessing your registry."
    }

    $AccessControl = $SubKey.GetAccessControl()
    $AccessControl.SetAccessRule($AccessRule)
    $SubKey.SetAccessControl($AccessControl)

    try 
    {
        if ($Decision -eq 0) 
        {
            New-ItemProperty -Path  "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" -Name Name        -PropertyType String -Value $Name       
            New-ItemProperty -Path  "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" -Name Location    -PropertyType String -Value $Location   
            New-ItemProperty -Path  "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" -Name MountLetter -PropertyType String -Value $MountLetter
            New-ItemProperty -Path  "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" -Name Product     -PropertyType String -Value $Product
            New-ItemProperty -Path  "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" -Name Timestamp   -PropertyType DWord -Value $Timestamp.GetHashCode()
        } 
        else
        {
            Write-Warning "New-PSTrueCryptContainer operation has been cancelled."
        }
    }
    catch [System.UnauthorizedAccessException]
    {
        Write-Error "'UnauthorizedAccessException' has been thrown which prevents PSTrueCrypt from accessing your registry."
    }
}


#.ExternalHelp PSTrueCrypt-help.xml
function Remove-PSTrueCryptContainer 
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    [System.String]$SubKeyName = Get-SubKeyPath -Name $Name

    try
    {
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKey("SOFTWARE\PSTrueCrypt\$SubKeyName", $True)

        Write-Information -MessageData "Container settings has been deleted from registry." -InformationAction Continue
    }
    catch [System.ObjectDisposedException]
    {
        #The RegistryKey being manipulated is closed (closed keys cannot be accessed).
        Write-Error "'ObjectDisposedException' has been thrown which prevents you from removing this PSTrueCryptContainer.  This may be due
        to the key being 'closed'."
    }
    catch [System.ArgumentException],[System.ArgumentNullException]
    {
        #subkey does not specify a valid registry key, and throwOnMissingSubKey is true.
        #subkey is null.
        Write-Error "Unable to find a PSTrueCryptContainer that corresponds with $Name.  Are you sure the name is correct?  Use 
        Show-PSTrueCryptContainers to view all container settings."
    }
    catch [System.Security.SecurityException]
    {
        #The user does not have the permissions required to delete the key.
        Write-Error "'SecurityException' has been thrown which prevents you from removing this container setting." -RecommendedAction "You can 
        set the 'Set-ExecutionPolicy' to 'Bypass' and attempt again.  See the following link for more info: https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.security/set-executionpolicy"
    }
    catch [System.InvalidOperationException]
    {
        # subkey has child subkeys.
        Write-Error "Unable to remove PSTrueCryptContainer for unknown reason(s)."
    }
    catch [System.UnauthorizedAccessException]
    {
        #The user does not have the necessary registry rights.
        Write-Error "'UnauthorizedAccessException' has been thrown which prevents PSTrueCrypt from accessing your registry."
    }
}


#.ExternalHelp PSTrueCrypt-help.xml
function Show-PSTrueCryptContainers 
{
    Push-Location
    Set-Location -Path HKCU:\SOFTWARE\PSTrueCrypt

    try 
    {
        Get-ChildItem . -Recurse | ForEach-Object {
            Get-ItemProperty $_.PsPath
        }| Format-Table Name, Location, MountLetter, Product, Timestamp -AutoSize
    }
    catch [System.Security.SecurityException]
    {
        #The user does not have the permissions required to delete the key.
        Write-Error "'SecurityException' has been thrown which prevents you from viewing container setting." -RecommendedAction "You can 
        set the 'Set-ExecutionPolicy' to 'Bypass' and attempt again.  See the following link for more info: https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.security/set-executionpolicy"
    }

    Pop-Location
}


#.ExternalHelp PSTrueCrypt-help.xml
function Set-EnvironmentPathVariable
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [string]$PathVar
    )

    [int]$Results = 0

    $Regex = "(\w+)\\?$"

    try 
    {
        ($PathVar -match $Regex)
        $EnvPathName = $Matches[1]
        
        $Results += [OSVerification]::($EnvPathName+"Found")

        $IsValid = Test-Path $PathVar -IsValid
        
        if($IsValid -eq $True) {
            $Results += [OSVerification]::($EnvPathName+"Valid")
        }

        $IsVerified = Test-Path $PathVar
            
        if($IsVerified -eq $True) {
            $Results += [OSVerification]::($EnvPathName+"Verified")
        }

        if(Get-OSVerificationResults $EnvPathName $Results)
        {
            Write-Verbose -Message "$PathVar is valid and verified for the 'PATH' environment variable."

            $Decision = Get-Confirmation -Message "$PathVar will be added to the 'PATH' environment variable."

            if($Decision -eq $True)
            {
                try
                {
                    Write-Verbose -Message "Attempting to set $PathVar for the 'PATH' environment variable."

                    [System.Environment]::SetEnvironmentVariable("Path", $env:Path +";"+ $PathVar, [EnvironmentVariableTarget]::Machine)

                    Write-Information -MessageData "$PathVar has been set to 'PATH' environment variable." -InformationAction Continue
                }
                catch
                {
                    Write-Error "An error has been thrown which prevents you from modifiying the PATH registry." -RecommendedAction "You can set the 'Set-ExecutionPolicy' to 'Bypass' and attempt again.  See the following link for more info: https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.security/set-executionpolicy" -ErrorAction Stop
                }
            }
            else
            {
                Write-Warning "You have selected 'No', no changes to 'PATH' environment variable has been made." -WarningAction Continue
            }  
        }
        else 
        {
            Write-Warning "$PathVar is not valid!  No changes to 'PATH' environment variable has been made." -WarningAction Inquire
        }
    }
    catch
    {
        Write-Warning "$PathVar is not valid!  No changes to 'PATH' environment variable has been made." -WarningAction Inquire
    }
}


#internal function
function Edit-HistoryFile
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [array]$KeyfilePath
    )

    try
    {
        $PSHistoryFilePath = (Get-PSReadlineOption | Select-Object -ExpandProperty HistorySavePath)
        $PSHistoryTempFilePath = $PSHistoryFilePath+".tmp"

        Get-Content -Path $PSHistoryFilePath | ForEach-Object { $_ -replace "-KeyfilePath.*(?<!Mount\-TrueCrypt|mt)", "-KeyfilePath X:\XXXXX\XXXXX\XXXXX"} | Set-Content -Path $PSHistoryTempFilePath

        Copy-Item -Path $PSHistoryTempFilePath -Destination $PSHistoryFilePath -Force

        Remove-Item -Path $PSHistoryTempFilePath -Force
    }
    catch
    {
        Write-Error -Message "Unable to redact the history file!  When KeyfilePath is not null, PSTrueCrypt will make an attempt to remove the KeyfilePath value from the following file:"
        Write-Error -Message $PSHistoryFilePath -ErrorAction Inquire
    }
}

#internal function
function Get-PSTrueCryptContainer 
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    [System.String]$SubKeyName = Get-SubKeyPath -Name $Name

    try 
    {
        $Settings = @{
            TrueCryptContainerPath  = Get-ItemProperty "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" | Select-Object -ExpandProperty Location
            PreferredMountDrive     = Get-ItemProperty "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" | Select-Object -ExpandProperty MountLetter
            Product                 = Get-ItemProperty "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" | Select-Object -ExpandProperty Product
            Timestamp               = (Get-ItemProperty "HKCU:\SOFTWARE\PSTrueCrypt\$SubKeyName" | Select-Object -ExpandProperty Timestamp) -eq 1
        }
    }
    catch
    {
        Write-Error -Message "Unable to read registry for unknown reason(s)."
    }

    $Settings
}


# internal function
function Get-SubKeyPath
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $True)]
        [string]$Name
    )

    Push-Location
    Set-Location -Path HKCU:\SOFTWARE\PSTrueCrypt

    try 
    {
        Get-ChildItem . -Recurse | ForEach-Object {
            if ($Name -eq (Get-ItemProperty $_.PsPath).Name) 
            {
                $PSChildName = $_.PSChildName
            }
        }
    }
    catch 
    {
        Write-Error -Message "Unable to read registry for unknown reason(s)."
    }

    Pop-Location

    Write-Output $PSChildName
}


# internal function
function Get-TrueCryptMountParams 
{
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$TrueCryptContainerPath,

        [Parameter(Mandatory = $True, Position = 2)]
        [string]$PreferredMountDrive,

        [Parameter(Mandatory = $True, Position = 3)]
        [string]$Product,

        [Parameter(Mandatory = $False, Position = 4)]
        [array]$KeyfilePath,

        [Parameter(Mandatory = $False, Position = 5)]
        [bool]$Timestamp
    )

    $ParamsHash = @{
                        "/quit" = "";
                        "/volume" = "'$TrueCryptContainerPath'";
                        "/letter" = "'$PreferredMountDrive'";
                        "/auto" = "";
                        "/password" = "'{0}'";
                        "/explore" = "";
                    }

    $ParamsString = New-Object -TypeName "System.Text.StringBuilder";

    [void]$ParamsString.Insert(0, "& "+$Product+" ")

    if ($Timestamp) 
    {
        $ParamsHash.Add("/mountoption", "timestamp")
    }

    # add keyfile(s) if any to ParamsHash...
    if ($KeyfilePath.count -gt 0) 
    {
        $KeyfilePath | ForEach-Object { 
            $ParamsHash.Add("/keyfile", "'$_'")
        }
    }
    
    # populate ParamsString with ParamsHash data...
    $ParamsHash.GetEnumerator() | ForEach-Object {
        # if no value assigned to this TrueCrypt attribute, then just append attribute to ParamsString...
        if ($_.Value.Equals(""))
        {
            [void]$ParamsString.AppendFormat("{0}", $_.Key)
        }
        else
        {
            [void]$ParamsString.AppendFormat("{0} {1}", $_.Key, $_.Value)
        }

        [void]$ParamsString.Append(" ")
    }
    
    $ParamsString.ToString().TrimEnd(" ");
}


# internal function
function Get-TrueCryptDismountParams
{
    Param
    (
        [Parameter(Mandatory = $False)]
        [string]$Drive,

        [Parameter(Mandatory = $True)]
        [string]$Product
    )

    $ParamsHash = @{
                    "/quit" = "";
                    "/dismount" = $Drive
                }
    
    # Force dismount for all TrueCrypt volumes? ...
    if($Drive -eq "")
    {
        $ParamsHash.Add("/force", "")
    }

    $ParamsString = New-Object -TypeName "System.Text.StringBuilder";

    [void]$ParamsString.Insert(0, "& "+$Product+" ")

    $ParamsHash.GetEnumerator() | ForEach-Object {
        if ($_.Value.Equals("")) 
        {
            [void]$ParamsString.AppendFormat("{0}", $_.Key)
        }
        else
        {
            [void]$ParamsString.AppendFormat("{0} {1}", $_.Key, $_.Value)
        }

        [void]$ParamsString.Append(" ")
    }
    
    return $ParamsString.ToString().TrimEnd(" ");
}


# internal function
# ref: http://stackoverflow.com/a/24649481
function Get-Confirmation
{
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$Message
    )
    
    $Question = 'Are you sure you want to proceed?'

    $Choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $Choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList "&Yes"))
    $Choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList "&No"))

    $Decision = $Host.UI.PromptForChoice($Message, $Question, $Choices, 1)

    $Decision -eq 0
}


# internal function
function Invoke-DismountAll
{
    Param
    (
        [ValidateSet("TrueCrypt", "VeraCrypt")]
        [string]$Product
    )

    # construct arguments for Force dismount(s)...
    [string]$Expression = Get-TrueCryptDismountParams -Product $Product

    try
    {
        Invoke-Expression $Expression
        $HasXCryptDismountFailed = $False
    }
    catch 
    {
        $HasXCryptDismountFailed = $True
    }
    finally
    {
        if($HasXCryptDismountFailed -eq $False)
        {
            Write-Information -MessageData "All $Product containers have successfully dismounted.  Please verify." -InformationAction Continue
        }
        else 
        {
            Write-Error "Dismounting $Product containers has failed!"
        }
    }
}


# internal function
# ref: http://www.jonathanmedd.net/2014/01/testing-for-admin-privileges-in-powershell.html
function Test-IsAdmin 
{
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}


# internal function
function Get-OSVerificationResults
{
    Param
    (
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$EnvPathName,

        [Parameter(Mandatory = $True, Position = 2)]
        [int]$Results,

        [ValidateSet("Found", "Valid", "Verified", "Success")]
        [string]$ResultStep = "Success"
    )

    try 
    {
        ([OSVerification]::($EnvPathName+$ResultStep) -band $Results)/[OSVerification]::($EnvPathName+$ResultStep) -eq $True
    }
    catch
    {
        $False
    }
}

function Initialize
{
    Add-Type -AssemblyName System.Windows.Forms 

    [int]$Results = 0;

    $Regex = "(\w+)\\?$"

    ($Env:Path).Split(';') | ForEach-Object {

        ($_ -match $Regex)
        $EnvPathName = $Matches[1]
        
        if(($EnvPathName -eq "TrueCrypt") -or ($EnvPathName -eq "VeraCrypt"))
        {
            $Results += [OSVerification]::($EnvPathName+"Found")

            try
            {
                Write-Verbose -Message "$EnvPathName has been found in the 'PATH' environment variable and will now be tested."
                
                $IsValid = Test-Path $_ -IsValid
                
                if($IsValid -eq $True) {
                     $Results += [OSVerification]::($EnvPathName+"Valid")

                    $IsVerified = Test-Path $_
                    
                    if($IsVerified -eq $True) {
                        $Results += [OSVerification]::($EnvPathName+"Verified")
                    }
                }
            }
            # should be safe to swallow.  any discrepanceis will result in the Get-OSVerificationResults call...
            catch{ }

            if(Get-OSVerificationResults $EnvPathName $Results)
            {
                Write-Verbose -Message "$EnvPathName has been successfully tested in the 'PATH' environment variable."
            }
            else
            {
                Write-Warning "The module PSTrueCrypt has detected the following PATH has failed: $_"
                $message = "To reset $EnvPathName's 'PATH' environment system variable, use the Set-$EnvPathName{0}PathVariable function." -f ""
                Write-Warning $message
                $message = "For an example: PS E:>Set-$EnvPathName{0}PathVariable 'C:\Program Files\TrueCrypt\'" -f ""
                Write-Warning $message
                Write-Warning "Afterwards, restart Powershell.  Upon restart, if the original path is still being used logout and try again."
            }
        }
    }
}


enum OSVerification {
    TrueCryptFound = 1
    VeraCryptFound = 2
                
    TrueCryptValid = 4
    VeraCryptValid = 8
     
    TrueCryptVerified = 16
    VeraCryptVerified = 32

    TrueCryptSuccess = 21
    VeraCryptSuccess = 42
}
Initialize

Set-Alias -Name mt -Value Mount-TrueCrypt
Set-Alias -Name dt -Value Dismount-TrueCrypt
Set-Alias -Name dtf -Value Dismount-TrueCryptForceAll

$ErrorRes = New-Object -TypeName 'System.Resources.ResXResourceSet' -ArgumentList $PSScriptRoot"\resx\Error.resx"
$InformationRes = New-Object -TypeName 'System.Resources.ResXResourceSet' -ArgumentList $PSScriptRoot"\resx\Information.resx"
$VerboseRes = New-Object -TypeName 'System.Resources.ResXResourceSet' -ArgumentList $PSScriptRoot"\resx\Verbose.resx"
$WarningRes = New-Object -TypeName 'System.Resources.ResXResourceSet' -ArgumentList $PSScriptRoot"\resx\Warning.resx"