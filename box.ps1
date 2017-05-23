<#

#OPTIONAL

	** Windows 7 **
	Should upgrade to WMF 5 first for reduced errors
	https://www.microsoft.com/en-us/download/details.aspx?id=50395

	# If Dev Machine
	[Environment]::SetEnvironmentVariable("BoxStarter:InstallDev", "1", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:InstallDev", "1", "Process") # for right now

    [Environment]::SetEnvironmentVariable("BoxStarter:DataDrive", "D", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:DataDrive", "D", "Process") # for right now

    [Environment]::SetEnvironmentVariable("BoxStarter:SourceCodeFolder", "git", "Machine") # relative path to for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:SourceCodeFolder", "git", "Process") # for right now

	[Environment]::SetEnvironmentVariable("BoxStarter:SkipWindowsUpdate", "1", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:SkipWindowsUpdate", "1", "Process") # for right now

	[Environment]::SetEnvironmentVariable("BoxStarter:EnableWindowsAuthFeature", "1", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:EnableWindowsAuthFeature", "1", "Process") # for right now

	[Environment]::SetEnvironmentVariable("choco:sqlserver2014:isoImage", "D:\Downloads\en_sql_server_2014_rc_2_x64_dvd_8509698.iso", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("choco:sqlserver2014:isoImage", "D:\Downloads\en_sql_server_2014_rc_2_x64_dvd_8509698.iso", "Process") # for right now

	[Environment]::SetEnvironmentVariable("choco:sqlserver2016:isoImage", "D:\Downloads\en_sql_server_2016_rc_2_x64_dvd_8509698.iso", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("choco:sqlserver2016:isoImage", "D:\Downloads\en_sql_server_2016_rc_2_x64_dvd_8509698.iso", "Process") # for right now


	# If Home Machine
	[Environment]::SetEnvironmentVariable("BoxStarter:InstallHome", "1", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:InstallHome", "1", "Process") # for right now

#START
	START http://boxstarter.org/package/nr/url?http://boxstarter.org/package/nr/url?https://raw.githubusercontent.com/JonCubed/boxstarter/master/box.ps1

wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" -InstallDev -SkipWindowsUpdate -SqlServer2014IsoImage 'c:\sql2014\en_sql_server_2014_standard_edition_x64_dvd_3932034.iso' }
#>

$Boxstarter.RebootOk = $true
$Boxstarter.NoPassword = $false
$Boxstarter.AutoLogin = $true

$checkpointPrefix = 'BoxStarter:Checkpoint:'

function Get-CheckpointName {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointName
    )
    return "$checkpointPrefix$CheckpointName"
}

function Set-Checkpoint {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointName,

        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointValue
    )

    $key = Get-CheckpointName $CheckpointName
    [Environment]::SetEnvironmentVariable($key, $CheckpointValue, "Machine") # for reboots
    [Environment]::SetEnvironmentVariable($key, $CheckpointValue, "Process") # for right now
}

function Get-Checkpoint {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $CheckpointName
    )

    $key = Get-CheckpointName $CheckpointName
    [Environment]::GetEnvironmentVariable($key, "Process")
}

function Clear-Checkpoints {
    $checkpointMarkers = Get-ChildItem Env: | where { $_.name -like "$checkpointPrefix*" } | Select -ExpandProperty name
    foreach ($checkpointMarker in $checkpointMarkers) {
        [Environment]::SetEnvironmentVariable($checkpointMarker, '', "Machine")
        [Environment]::SetEnvironmentVariable($checkpointMarker, '', "Process")
    }
}

function Use-Checkpoint {
    param(
        [string]
        $CheckpointName,

        [string]
        $SkipMessage,

        [scriptblock]
        $Function
    )

    $checkpoint = Get-Checkpoint -CheckpointName $CheckpointName

    if (-not $checkpoint) {
        $Function.Invoke($Args)

        Set-Checkpoint -CheckpointName $CheckpointName -CheckpointValue 1
    }
    else {
        Write-BoxstarterMessage $SkipMessage
    }
}

function Get-OSInformation {
    $osInfo = Get-WmiObject -class Win32_OperatingSystem `
        | Select-Object -First 1

    return ConvertFrom-String -Delimiter \. -PropertyNames Major, Minor, Build  $osInfo.version
}

function Test-IsOSWindows10 {
    $osInfo = Get-OSInformation

    return $osInfo.Major -eq 10
}

function Get-SystemDrive {
    return $env:SystemDrive[0]
}

function Get-DataDrive {
    $driveLetter = Get-SystemDrive

    if ((Test-Path env:\BoxStarter:DataDrive) -and (Test-Path $env:BoxStarter:DataDrive)) {
        $driveLetter = $env:BoxStarter:DataDrive
    }

    return $driveLetter
}

function Install-WindowsUpdate {
    if (Test-Path env:\BoxStarter:SkipWindowsUpdate) {
        return
    }

    Enable-MicrosoftUpdate
    Install-WindowsUpdate -AcceptEula
    #if (Test-PendingReboot) { Invoke-Reboot }
}

function Install-WebPackage {
    param(
        $packageName,
        [ValidateSet('exe', 'msi')]
        $fileType,
        $installParameters,
        $downloadFolder,
        $url,
        $filename
    )

    if ([String]::IsNullOrEmpty($filename)) {
        $filename = Split-Path $url -Leaf
    }

    $fullFilename = Join-Path $downloadFolder $filename

    if (test-path $fullFilename) {
        Write-BoxstarterMessage "$fullFilename already exists"
        return
    }

    Get-ChocolateyWebFile $packageName $fullFilename $url
    Install-ChocolateyInstallPackage $packageName $fileType $installParameters $fullFilename
}

function Install-WebPackageWithCheckpoint {
    param(
        $packageName,
        [ValidateSet('exe', 'msi')]
        $fileType,
        $installParameters,
        $downloadFolder,
        $url,
        $filename
    )

    Use-Checkpoint `
        -Function ${Function:Install-WebPackage} `
        -CheckpointName $packageName `
        -SkipMessage "$packageName is already installed" `
        $packageName `
        $fileType `
        $installParameters `
        $downloadFolder `
        $url `
        $filename
}

function Install-CoreApps {
    choco install googlechrome              --limitoutput
    choco install notepadplusplus.install   --limitoutput
    choco install paint.net                 --limitoutput
    choco install 7zip.install              --limitoutput
    choco install skype                     --limitoutput
    choco install adobereader               --limitoutput
}

function Set-ChocoCoreAppPins {
    # pin apps that update themselves
    choco pin add -n=googlechrome
    choco pin add -n='paint.net'
}

function Install-SqlServer2014 {
    param (
        $InstallDrive
    )

    if (-not(Test-Path env:\choco:sqlserver2014:isoImage) -and -not(Test-Path env:\choco:sqlserver2014:setupFolder)) {
        return
    }

    $dataPath = Join-Path $InstallDrive "Data\Sql"

    #rejected by chocolatey.org since iso image is required  :|
    $sqlPackageSource = "https://www.myget.org/F/nm-chocolatey-packs/api/v2"

    # SQL2014 has dependency on .net 3.5
    choco install NetFx3                 --source windowsfeatures --limitoutput

    if (Test-PendingReboot) { Invoke-Reboot }

    # Note: No support for Windows 7 https://msdn.microsoft.com/en-us/library/ms143506.aspx
    $env:choco:sqlserver2014:INSTALLSQLDATADIR = $dataPath
    $env:choco:sqlserver2014:INSTANCEID = "sql2014"
    $env:choco:sqlserver2014:INSTANCENAME = "sql2014"
    $env:choco:sqlserver2014:FEATURES = "SQLENGINE,ADV_SSMS"
    $env:choco:sqlserver2014:AGTSVCACCOUNT = "NT Service\SQLAgent`$SQL2014"
    $env:choco:sqlserver2014:SQLSVCACCOUNT = "NT Service\MSSQL`$SQL2014"
    $env:choco:sqlserver2014:SQLCOLLATION = "SQL_Latin1_General_CP1_CI_AS"
    choco install sqlserver2014 --source=$sqlPackageSource
}

function Install-SqlServer2016 {
    param (
        $InstallDrive
    )

    if (-not (Test-Path env:\choco:sqlserver2016:isoImage) -and -not(Test-Path env:\choco:sqlserver2016:setupFolder)) {
        return
    }

    $dataPath = Join-Path $InstallDrive "Data\Sql"

    #rejected by chocolatey.org since iso image is required  :|
    $sqlPackageSource = "https://www.myget.org/F/nm-chocolatey-packs/api/v2"

    # Note: No support for Windows 7 https://msdn.microsoft.com/en-us/library/ms143506.aspx
    $env:choco:sqlserver2016:INSTALLSQLDATADIR = $dataPath
    $env:choco:sqlserver2016:INSTANCEID = "sql2016"
    $env:choco:sqlserver2016:INSTANCENAME = "sql2016"
    $env:choco:sqlserver2016:AGTSVCACCOUNT = "NT Service\SQLAgent`$SQL2016"
    $env:choco:sqlserver2016:SQLSVCACCOUNT = "NT Service\MSSQL`$SQL2016"
    $env:choco:sqlserver2016:SQLCOLLATION = "SQL_Latin1_General_CP1_CI_AS"
    choco install sqlserver2016 --source=$sqlPackageSource
}

function Install-SqlTools {
    param (
        $DownloadFolder
    )

    choco install sql-server-management-studio --limitoutput

    #Install-WebPackageWithCheckpoint 'SQL Source Control V3.8' 'exe' '/quiet' $DownloadFolder ftp://support.red-gate.com/patches/SQLSourceControlFrequentUpdates/23Jul2015/SQLSourceControlFrequentUpdates_3.8.21.179.exe

    #Install-WebPackageWithCheckpoint 'SQL Compare V11.6' 'exe' '/quiet' $DownloadFolder http://download.red-gate.com/checkforupdates/SQLCompare/SQLCompare_11.6.11.2463.exe
}

function Install-HomeApps {
    if (-not(Test-Path env:\BoxStarter:InstallHome)) {
        return
    }

    choco install lastpass	--limitoutput
}

function Install-CoreDevApps {
    choco install dotnetcore-sdk    --limitoutput

    choco install git.install -params '"/GitAndUnixToolsOnPath"' --limitoutput
    choco install firefox                   --limitoutput
    choco install docker-for-windows        --limitoutput
    choco install gitkraken 	            --limitoutput
    choco install resharper-platform        --limitoutput
    choco install prefix               	    --limitoutput
    choco install nodejs                    --limitoutput
}

function Install-DevOpsTools {
    choco install terraform           	    --limitoutput
    choco install packer               	    --limitoutput
}

function Install-DevTools {
    #choco install jdk8		        	    --limitoutput
    choco install slack                     --limitoutput
    choco install redis-desktop-manager     --limitoutput
    choco install putty               	    --limitoutput
    choco install fiddler4               	--limitoutput
    choco install winscp              	    --limitoutput
    #choco install nmap                	    --limitoutput
    choco install nugetpackageexplorer	    --limitoutput
    choco install diffmerge				    --limitoutput

    choco install poshgit                   --limitoutput
    choco install sourcetree 	            --limitoutput
    choco install teamviewer                --limitoutput
    choco install commandwindowhere   	    --limitoutput
    #choco install virtualbox          	    --limitoutput
    choco install nuget.commandline		    --limitoutput
    #choco install rdcman 				    --limitoutput
}

function Install-VisualStudio2017 {
    # install visual studio 2017 community and extensions
    choco install visualstudio2017community                 --limitoutput
    choco install visualstudio2017-workload-netcoretools    --limitoutput
    choco install visualstudio2017-workload-netweb
}

function Install-VisualStudio2015 {
    # install visual studio 2015 community and extensions
    choco install visualstudio2015community --limitoutput # -packageParameters "--AdminFile https://raw.githubusercontent.com/JonCubed/boxstarter/master/config/AdminDeployment.xml"
}

function Install-VisualStudio2015Extensions {
    param (
        $DownloadFolder
    )

    Install-ChocolateyVsixPackage 'PowerShell Tools for Visual Studio 2015' https://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597/file/199313/1/PowerShellTools.14.0.vsix
    Install-ChocolateyVsixPackage 'Productivity Power Tools 2015' https://visualstudiogallery.msdn.microsoft.com/34ebc6a2-2777-421d-8914-e29c1dfa7f5d/file/169971/1/ProPowerTools.vsix
    Install-ChocolateyVsixPackage 'SideWaffle Template Pack' https://visualstudiogallery.msdn.microsoft.com/a16c2d07-b2e1-4a25-87d9-194f04e7a698/referral/110630
    Install-ChocolateyVsixPackage 'Glyphfriend' https://visualstudiogallery.msdn.microsoft.com/5fd24afb-b3b2-4cec-9b03-1cfcec6123aa/file/150806/7/Glyphfriend.vsix
    Install-ChocolateyVsixPackage 'Web Compiler' https://visualstudiogallery.msdn.microsoft.com/3b329021-cd7a-4a01-86fc-714c2d05bb6c/file/164873/35/Web%20Compiler%20v1.10.300.vsix
    Install-ChocolateyVsixPackage 'Image Optimizer' https://visualstudiogallery.msdn.microsoft.com/a56eddd3-d79b-48ac-8c8f-2db06ade77c3/file/38601/34/Image%20Optimizer%20v3.3.51.vsix
    Install-ChocolateyVsixPackage 'Package Installer' https://visualstudiogallery.msdn.microsoft.com/753b9720-1638-4f9a-ad8d-2c45a410fd74/file/173807/20/Package%20Installer%20v1.5.69.vsix
    Install-ChocolateyVsixPackage 'BuildVision' https://visualstudiogallery.msdn.microsoft.com/23d3c821-ca2d-4e1a-a005-4f70f12f77ba/file/95980/13/BuildVision.vsix
    Install-ChocolateyVsixPackage 'File Nesting' https://visualstudiogallery.msdn.microsoft.com/3ebde8fb-26d8-4374-a0eb-1e4e2665070c/file/123284/32/File%20Nesting%20v2.5.62.vsix

    #Install-WebPackage '.NET Core Visual Studio Extension' 'exe' '/quiet' $DownloadFolder https://marketplace.visualstudio.com/items?itemName=JacquesEloff.MicrosoftASPNETandWebTools-9689 'DotNetCore.1.0.1-VS2015Tools.Preview2.0.3' # for visual studio
}

function Install-VisualStudioCode {
    # install visual studio code and extensions
    choco install visualstudiocode  --limitoutput

    Update-Path
}

function Install-VSCodeExtensions {
    # need to launch vscode so user folders are created as we can install extensions
    Start-Process code
    Start-Sleep -s 10

    code --install-extension ms-vscode.csharp
    code --install-extension ms-vscode.PowerShell
    code --install-extension DavidAnson.vscode-markdownlint
    code --install-extension johnpapa.Angular2
    code --install-extension donjayamanne.githistory
    code --install-extension eg2.tslint
    code --install-extension lukehoban.Go
    code --install-extension msjsdiag.debugger-for-chrome
    code --install-extension cake-build.cake-vscode
    code --install-extension mauve.terraform
    code --install-extension Arjun.swagger-viewer
    code --install-extension docthis
    code --install-extension hnw.vscode-auto-open-markdown-preview
    code --install-extension wk-j.cake-runner
    code --install-extension EditorConfig.editorconfig
    code --install-extension DavidAnson.vscode-markdownlin
    code --install-extension djabraham.vscode-yaml-validation
    code --install-extension robertohuertasm.vscode-icons
    code --install-extension PeterJausovec.vscode-docker
}

function Install-InternetInformationServices {
    # Enable Internet Information Services Feature - will enable a bunch of things by default
    choco install IIS-WebServerRole                 --source windowsfeatures --limitoutput

    # Web Management Tools Features
    choco install IIS-ManagementScriptingTools      --source windowsfeatures --limitoutput
    choco install IIS-IIS6ManagementCompatibility   --source windowsfeatures --limitoutput # installs IIS Metbase

    # Common Http Features
    choco install IIS-HttpRedirect                  --source windowsfeatures --limitoutput

    # .NET Framework 4.5/4.6 Advance Services
    choco install NetFx4Extended-ASPNET45           --source windowsfeatures --limitoutput # installs ASP.NET 4.5/4.6

    # Application Development Features
    choco install IIS-NetFxExtensibility45          --source windowsfeatures --limitoutput # installs .NET Extensibility 4.5/4.6
    choco install IIS-ISAPIFilter                   --source windowsfeatures --limitoutput # required by IIS-ASPNET45
    choco install IIS-ISAPIExtensions               --source windowsfeatures --limitoutput # required by IIS-ASPNET45
    choco install IIS-ASPNET45                      --source windowsfeatures --limitoutput # installs support for ASP.NET 4.5/4.6
    choco install IIS-ApplicationInit               --source windowsfeatures --limitoutput

    # Health And Diagnostics Features
    choco install IIS-LoggingLibraries              --source windowsfeatures --limitoutput # installs Logging Tools
    choco install IIS-RequestMonitor                --source windowsfeatures --limitoutput
    choco install IIS-HttpTracing                   --source windowsfeatures --limitoutput
    choco install IIS-CustomLogging                 --source windowsfeatures --limitoutput

    # Performance Features
    choco install IIS-HttpCompressionDynamic        --source windowsfeatures --limitoutput

    # Security Features
    choco install IIS-BasicAuthentication           --source windowsfeatures --limitoutput

    if (Test-Path env:\BoxStarter:EnableWindowsAuthFeature) {
        choco install IIS-WindowsAuthentication     --source windowsfeatures --limitoutput
    }
}

function Install-DevFeatures {
    # Bash for windows
    $features = choco list --source windowsfeatures
    if ($features | Where-Object {$_ -like "*Linux*"}) {
        choco install Microsoft-Windows-Subsystem-Linux --source windowsfeatures --limitoutput
    }

    # windows containers
    Enable-WindowsOptionalFeature -Online -FeatureName containers -All

    # hyper-v (required for windows containers)
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

}

function Install-NpmPackages {
    npm install -g typescript
    npm install -g angular-cli # angular2 cli
}

function Install-PowerShellModules {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
    Install-Module -Name Carbon
    Install-Module -Name PowerShellHumanizer
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Untrusted'
}

function Set-ChocoDevAppPins {
    # pin apps that update themselves
    choco pin add -n=visualstudiocode
    choco pin add -n=visualstudio2015community
    choco pin add -n=sourcetree
    choco pin add -n=gitkraken
    choco pin add -n=firefox
}

function Set-RegionalSettings {
    #http://stackoverflow.com/questions/4235243/how-to-set-timezone-using-powershell
    &"$env:windir\system32\tzutil.exe" /s "AUS Eastern Standard Time"

    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sShortDate -Value 'dd MMM yy'
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sCountry -Value Australia
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sShortTime -Value 'hh:mm tt'
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sTimeFormat -Value 'hh:mm:ss tt'
    Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sLanguage -Value ENA
}

function Set-BaseSettings {
    Update-ExecutionPolicy -Policy Unrestricted

    $sytemDrive = Get-SystemDrive
    Set-Volume -DriveLetter $sytemDrive -NewFileSystemLabel "OS"
    Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -DisableShowProtectedOSFiles -EnableShowFileExtensions -EnableShowFullPathInTitleBar
    Set-TaskbarOptions -Combine Never

    # replace command prompt with powershell in start menu and win+x
    Set-CornerNavigationOptions -EnableUsePowerShellOnWinX
}

function Set-UserSettings {
    choco install taskbar-never-combine             --limitoutput
    choco install explorer-show-all-folders         --limitoutput
    choco install explorer-expand-to-current-folder --limitoutput
}

function Set-BaseDesktopSettings {
    if (Test-IsOSWindows10) {
        return
    }

    Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Google\Chrome\Application\chrome.exe"
}

function Set-DevDesktopSettings {
    if (Test-IsOSWindows10) {
        return
    }

    Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"

    Install-ChocolateyFileAssociation ".dll" "$env:LOCALAPPDATA\JetBrains\Installations\dotPeek06\dotPeek64.exe"
}

function Update-WindowsLibraries {
    $dataDriveLetter = Get-DataDrive
    $dataDrive = "$dataDriveLetter`:"

    if (Get-SystemDrive -eq $dataDriveLetter) {
        return
    }

    Write-BoxstarterMessage "Configuring $dataDrive\"

    Set-Volume -DriveLetter $dataDriveLetter -NewFileSystemLabel "Data"

    $userDataPath = "$dataDrive\Data\Documents"
    $mediaPath = "$dataDrive\Media"

    Move-WindowsLibrary -libraryName "My Pictures" -newPath (Join-Path $userDataPath "Pictures")
    Move-WindowsLibrary -libraryName "Personal"    -newPath (Join-Path $userDataPath "Documents")
    Move-WindowsLibrary -libraryName "Desktop"     -newPath (Join-Path $userDataPath "Desktop")
    Move-WindowsLibrary -libraryName "My Video"    -newPath (Join-Path $mediaPath "Videos")
    Move-WindowsLibrary -libraryName "My Music"    -newPath (Join-Path $mediaPath "Music")
    Move-WindowsLibrary -libraryName "Downloads"   -newPath "$dataDrive\Downloads"
}

function Move-WindowsLibrary {
    param(
        $libraryName,
        $newPath
    )

    if (-not (Test-Path $newPath)) {
        Move-LibraryDirectory -libraryName $libraryName -newPath $newPath
    }
}

function New-SourceCodeFolder {
    $sourceCodeFolder = 'sourcecode'
    if (Test-Path env:\BoxStarter:SourceCodeFolder) {
        $sourceCodeFolder = $env:BoxStarter:SourceCodeFolder
    }

    if ([System.IO.Path]::IsPathRooted($sourceCodeFolder)) {
        $sourceCodePath = $sourceCodeFolder
    }
    else {
        $drivePath = Get-DataDrive
        $sourceCodePath = Join-Path "$drivePath`:" $sourceCodeFolder
    }

    if (-not (Test-Path $sourceCodePath)) {
        New-Item $sourceCodePath -ItemType Directory
    }
}

function New-InstallCache {
    param
    (
        [String]
        $InstallDrive
    )

    $tempInstallFolder = Join-Path $InstallDrive "temp\install-cache"

    if (-not (Test-Path $tempInstallFolder)) {
        New-Item $tempInstallFolder -ItemType Directory
    }

    return $tempInstallFolder
}

function Enable-ChocolateyFeatures {
    choco feature enable --name=allowGlobalConfirmation
}

function Disable-ChocolateyFeatures {
    choco feature disable --name=allowGlobalConfirmation
}

function Update-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

$dataDriveLetter = Get-DataDrive
$dataDrive = "$dataDriveLetter`:"
$tempInstallFolder = New-InstallCache -InstallDrive $dataDrive

Use-Checkpoint -Function ${Function:Set-RegionalSettings} -CheckpointName 'RegionalSettings' -SkipMessage 'Regional settings are already configured'

# SQL Server requires some KB patches before it will work, so windows update first
Write-BoxstarterMessage "Windows update..."
Install-WindowsUpdate

# disable chocolatey default confirmation behaviour (no need for --yes)
Use-Checkpoint -Function ${Function:Enable-ChocolateyFeatures} -CheckpointName 'IntialiseChocolatey' -SkipMessage 'Chocolatey features already configured'

Use-Checkpoint -Function ${Function:Set-BaseSettings} -CheckpointName 'BaseSettings' -SkipMessage 'Base settings are already configured'
Use-Checkpoint -Function ${Function:Set-UserSettings} -CheckpointName 'UserSettings' -SkipMessage 'User settings are already configured'

Write-BoxstarterMessage "Starting installs"

Use-Checkpoint -Function ${Function:Install-CoreApps} -CheckpointName 'InstallCoreApps' -SkipMessage 'Core apps are already installed'

# pin chocolatey app that self-update
Use-Checkpoint -Function ${Function:Set-ChocoCoreAppPins} -CheckpointName 'ChocoCoreAppPins' -SkipMessage 'Core apps are already pinned'

Use-Checkpoint -Function ${Function:Set-BaseDesktopSettings} -CheckpointName 'BaseDesktopSettings' -SkipMessage 'Base desktop settings are already configured'

if (Test-Path env:\BoxStarter:InstallDev) {
    Write-BoxstarterMessage "Installing dev apps"

    #enale dev related windows features
    Use-Checkpoint -Function ${Function:Install-DevFeatures} -CheckpointName 'DevFeatures' -SkipMessage 'Windows dev features are already configured'

    #setup iis
    Use-Checkpoint -Function ${Function:Install-InternetInformationServices} -CheckpointName 'InternetInformationServices' -SkipMessage 'IIS features are already configured'

    #install sql tools
    Use-Checkpoint -Function ${Function:Install-SqlTools} -CheckpointName 'SqlTools' -SkipMessage 'SQL Tools are already installed'

    if (Test-PendingReboot) { Invoke-Reboot }

    #install sql server 2014
    Use-Checkpoint -Function ${Function:Install-SqlServer2014} -CheckpointName 'SqlServer2014' -SkipMessage 'SQL Server 2014 are already installed' $dataDrive

   	if (Test-PendingReboot) { Invoke-Reboot }

    #install sql server 2016
    Use-Checkpoint -Function ${Function:Install-SqlServer2016} -CheckpointName 'SqlServer2016' -SkipMessage 'SQL Server 2016 are already installed' $dataDrive

    #install vs2015 an extensions
    Use-Checkpoint -Function ${Function:Install-VisualStudio2015} -CheckpointName 'VisualStudio2015' -SkipMessage 'Visual Studio 2015 is already installed'
    Use-Checkpoint -Function ${Function:Install-VisualStudio2015Extensions} -CheckpointName 'VS2015Extensions' -SkipMessage 'Visual Studio 2015 extensions are already installed' $tempInstallFolder

    #install vs2017
    Use-Checkpoint -Function ${Function:Install-VisualStudio2017} -CheckpointName 'VisualStudio2017' -SkipMessage 'Visual Studio 2017 is already installed'

    #install vscode and extensions
    Use-Checkpoint -Function ${Function:Install-VisualStudioCode} -CheckpointName 'VisualStudioCode' -SkipMessage 'VSCode is already installed'
    Use-Checkpoint -Function ${Function:Install-VSCodeExtensions} -CheckpointName 'VSCodeExtensions' -SkipMessage 'VSCode extensions are already installed'

    #install core apps needed for dev
    Use-Checkpoint -Function ${Function:Install-CoreDevApps} -CheckpointName 'CoreDevApps' -SkipMessage 'Core dev apps are already installed'

    #install extra apps used for dev
    Use-Checkpoint -Function ${Function:Install-DevTools} -CheckpointName 'DevTools' -SkipMessage 'Dev tools are already installed'

    #install devops apps used for dev
    Use-Checkpoint -Function ${Function:Install-DevOpsTools} -CheckpointName 'DevOpsTools' -SkipMessage 'DevOps tools are already installed'

    # make folder for source code
    New-SourceCodeFolder

    # pin chocolatey app that self-update
    Use-Checkpoint -Function ${Function:Set-ChocoDevAppPins} -CheckpointName 'ChocoDevAppPins' -SkipMessage 'Dev apps are already pinned'

    Use-Checkpoint -Function ${Function:Set-DevDesktopSettings} -CheckpointName 'DevDesktopSettings' -SkipMessage 'Dev desktop settings are already configured'
}

#install apps for home use
Use-Checkpoint -Function ${Function:Install-HomeApps} -CheckpointName 'HomeApps' -SkipMessage 'Home apps are already installed'

#move windows libraries to data drive
Use-Checkpoint -Function ${Function:Update-WindowsLibraries} -CheckpointName 'WindowsLibraries' -SkipMessage 'Libraries are already configured'

# install chocolatey as last choco package
choco install chocolatey --limitoutput

# re-enable chocolatey default confirmation behaviour
Use-Checkpoint -Function ${Function:Disable-ChocolateyFeatures} -CheckpointName 'DisableChocolatey' -SkipMessage 'Chocolatey features already configured'

if (Test-PendingReboot) { Invoke-Reboot }

# reload path environment variable
Update-Path

Use-Checkpoint -Function ${Function:Install-NpmPackages} -CheckpointName 'NpmPackages' -SkipMessage 'NPM packages are already installed'

Use-Checkpoint -Function ${Function:Install-PowerShellModules} -CheckpointName 'PowerShellModules' -SkipMessage 'PowerShell modules are already installed'

# set HOME to user profile for git
[Environment]::SetEnvironmentVariable("HOME", $env:UserProfile, "User")

# rerun windows update after we have installed everything
Write-BoxstarterMessage "Windows update..."
Install-WindowsUpdate

Clear-Checkpoints
