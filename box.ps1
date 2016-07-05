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

	[Environment]::SetEnvironmentVariable("choco:sqlserver2016:isoImage", "D:\Downloads\en_sql_server_2016_rc_2_x64_dvd_8509698.iso", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("choco:sqlserver2016:isoImage", "D:\Downloads\en_sql_server_2016_rc_2_x64_dvd_8509698.iso", "Process") # for right now


	# If Home Machine
	[Environment]::SetEnvironmentVariable("BoxStarter:InstallHome", "1", "Machine") # for reboots
	[Environment]::SetEnvironmentVariable("BoxStarter:InstallHome", "1", "Process") # for right now

#START
	START http://boxstarter.org/package/nr/url?http://boxstarter.org/package/nr/url?https://raw.githubusercontent.com/JonCubed/boxstarter/master/box.ps1

#>

$Boxstarter.RebootOk=$true
$Boxstarter.NoPassword=$false
$Boxstarter.AutoLogin=$true

$checkpointPrefix = 'BoxStarter:Checkpoint:'

function Get-CheckpointName
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $CheckpointName
    )
    return "$checkpointPrefix$CheckpointName"
}

function Set-Checkpoint
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $CheckpointName,
        
        [Parameter(Mandatory=$true)]
        [string]
        $CheckpointValue
    )

    $key = Get-CheckpointName $CheckpointName
    [Environment]::SetEnvironmentVariable($key, $CheckpointValue, "Machine") # for reboots
	[Environment]::SetEnvironmentVariable($key, $CheckpointValue, "Process") # for right now
}

function Get-Checkpoint
{
    param
    (
        [Parameter(Mandatory=$true)]
        [string]
        $CheckpointName
    )

    $key = Get-CheckpointName $CheckpointName
	[Environment]::GetEnvironmentVariable($key, "Process")
}

function Clear-Checkpoints
{
    $checkpointMarkers = Get-ChildItem Env: | where { $_.name -like "$checkpointPrefix*" } | Select -ExpandProperty name
    foreach ($checkpointMarker in $checkpointMarkers) {        
	    [Environment]::SetEnvironmentVariable($checkpointMarker, '', "Machine")
	    [Environment]::SetEnvironmentVariable($checkpointMarker, '', "Process")
    }
}

function Get-SystemDrive
{
    return $env:SystemDrive[0]
}

function Get-DataDrive
{
    $driveLetter = Get-SystemDrive

    if((Test-Path env:\BoxStarter:DataDrive) -and (Test-Path $env:BoxStarter:DataDrive))
    {
        $driveLetter = $env:BoxStarter:DataDrive
    }

    return $driveLetter
}

function Install-WindowsUpdate
{
    if (Test-Path env:\BoxStarter:SkipWindowsUpdate)
    {
        return
    }

	Enable-MicrosoftUpdate
	Install-WindowsUpdate -AcceptEula
	if (Test-PendingReboot) { Invoke-Reboot }
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

    $done = Get-Checkpoint -CheckpointName $packageName
    
    if ($done) {
        Write-BoxstarterMessage "$packageName already installed"
        return
    }


    if ([String]::IsNullOrEmpty($filename))
    {
        $filename = Split-Path $url -Leaf
    }

    $fullFilename = Join-Path $downloadFolder $filename

    if (test-path $fullFilename) {
        Write-BoxstarterMessage "$fullFilename already exists"
        return
    }

    Get-ChocolateyWebFile $packageName $fullFilename $url
    Install-ChocolateyInstallPackage $packageName $fileType $installParameters $fullFilename

    Set-Checkpoint -CheckpointName $packageName -CheckpointValue 1
}

function Install-CoreApps
{
    choco install googlechrome              --limitoutput
    choco install flashplayerplugin         --limitoutput
    choco install notepadplusplus.install   --limitoutput
    choco install paint.net                 --limitoutput
    choco install 7zip.install              --limitoutput
    choco install skype                     --limitoutput
    choco install adobereader               --limitoutput
}

function Install-HomeApps
{
	choco install lastpass	--limitoutput
}

function Install-SqlServer
{
    param (
        $InstallDrive
    )

    $dataPath = Join-Path $InstallDrive "Data\Sql"

	#rejected by chocolatey.org since iso image is required  :|
	$sqlPackageSource = "https://www.myget.org/F/nm-chocolatey-packs/api/v2"

	choco install sqlstudio --source=$sqlPackageSource
    
    if ((Test-Path env:\choco:sqlserver2016:isoImage) -or (Test-Path env:\choco:sqlserver2016:setupFolder))
    {
		# Note: No support for Windows 7 https://msdn.microsoft.com/en-us/library/ms143506.aspx
		if (Test-PendingReboot) { Invoke-Reboot }
		$env:choco:sqlserver2016:INSTALLSQLDATADIR=$dataPath
		$env:choco:sqlserver2016:INSTANCEID="sql2016"
		$env:choco:sqlserver2016:INSTANCENAME="sql2016"
		$env:choco:sqlserver2016:AGTSVCACCOUNT="NT Service\SQLAgent`$SQL2016"
		$env:choco:sqlserver2016:SQLSVCACCOUNT="NT Service\MSSQL`$SQL2016"
		$env:choco:sqlserver2016:SQLCOLLATION="SQL_Latin1_General_CP1_CI_AS"
		choco install sqlserver2016 --source=$sqlPackageSource
    }
}

function Install-CoreDevApps
{
    choco install git.install -params '"/GitAndUnixToolsOnPath"' --limitoutput    
    choco install firefox                   --limitoutput
    choco install poshgit                   --limitoutput
    choco install resharper            	    --limitoutput
    choco install sourcetree 	            --limitoutput
    choco install dotpeek             	    --limitoutput
    choco install nodejs                    --limitoutput
    choco install teamviewer                --limitoutput
    choco install prefix               	    --limitoutput
    choco install commandwindowhere   	    --limitoutput
    choco install virtualbox          	    --limitoutput
    choco install nuget.commandline		    --limitoutput
	choco install rdcman 				    --limitoutput
}

function Install-DevTools
{
    param (
        $DownloadFolder
    )

	choco install jdk8		        	    --limitoutput
    choco install slack                     --limitoutput
    choco install redis-desktop-manager     --limitoutput
    choco install packer               	    --limitoutput
	choco install putty               	    --limitoutput
    choco install fiddler4               	--limitoutput
	choco install winscp              	    --limitoutput
	choco install nmap                	    --limitoutput
	choco install nugetpackageexplorer	    --limitoutput
	choco install diffmerge				    --limitoutput

    #Install-WebPackage 'Docker Toolbox' 'exe' '/SILENT /COMPONENTS="Docker,DockerMachine,DockerCompose,VirtualBox,Kitematic" /TASKS="modifypath"' $DownloadFolder https://github.com/docker/toolbox/releases/download/v1.11.2/DockerToolbox-1.11.2.exe
}

function Install-VisualStudio
{
    param (
        $DownloadFolder
    )

    # install visual studio 2015 community and extensions
    choco install visualstudio2015community --limitoutput # -packageParameters "--AdminFile https://raw.githubusercontent.com/JonCubed/boxstarter/master/config/AdminDeployment.xml"

    $VSCheckpoint = 'VSExtensions'
    $VSDone = Get-Checkpoint -CheckpointName $VSCheckpoint
    
    if (-not $VSDone) 
    {
        Install-ChocolateyVsixPackage 'PowerShell Tools for Visual Studio 2015' https://visualstudiogallery.msdn.microsoft.com/c9eb3ba8-0c59-4944-9a62-6eee37294597/file/199313/1/PowerShellTools.14.0.vsix
        Install-ChocolateyVsixPackage 'Productivity Power Tools 2015' https://visualstudiogallery.msdn.microsoft.com/34ebc6a2-2777-421d-8914-e29c1dfa7f5d/file/169971/1/ProPowerTools.vsix
        Install-ChocolateyVsixPackage 'SideWaffle Template Pack' https://visualstudiogallery.msdn.microsoft.com/a16c2d07-b2e1-4a25-87d9-194f04e7a698/referral/110630
        Install-ChocolateyVsixPackage 'Glyphfriend' https://visualstudiogallery.msdn.microsoft.com/5fd24afb-b3b2-4cec-9b03-1cfcec6123aa/file/150806/7/Glyphfriend.vsix
        Install-ChocolateyVsixPackage 'Web Compiler' https://visualstudiogallery.msdn.microsoft.com/3b329021-cd7a-4a01-86fc-714c2d05bb6c/file/164873/35/Web%20Compiler%20v1.10.300.vsix
        Install-ChocolateyVsixPackage 'Image Optimizer' https://visualstudiogallery.msdn.microsoft.com/a56eddd3-d79b-48ac-8c8f-2db06ade77c3/file/38601/34/Image%20Optimizer%20v3.3.51.vsix
        Install-ChocolateyVsixPackage 'Package Installer' https://visualstudiogallery.msdn.microsoft.com/753b9720-1638-4f9a-ad8d-2c45a410fd74/file/173807/20/Package%20Installer%20v1.5.69.vsix
        Install-ChocolateyVsixPackage 'BuildVision' https://visualstudiogallery.msdn.microsoft.com/23d3c821-ca2d-4e1a-a005-4f70f12f77ba/file/95980/13/BuildVision.vsix
        Install-ChocolateyVsixPackage 'File Nesting' https://visualstudiogallery.msdn.microsoft.com/3ebde8fb-26d8-4374-a0eb-1e4e2665070c/file/123284/32/File%20Nesting%20v2.5.62.vsix

        Install-WebPackage '.NET Core Visual Studio Extension' 'exe' '/quiet' $DownloadFolder https://go.microsoft.com/fwlink/?LinkId=798481 'DotNetCore.1.0.0.RC2-VS2015Tools.Preview1.exe' # for visual studio
        
        Set-Checkpoint -CheckpointName $VSCheckpoint -CheckpointValue 1
    }

    # install visual studio code and extensions
    choco install visualstudiocode	--limitoutput

    Update-Path

    $VSCodeCheckpoint = 'VSCodeExtensions'
    $VSCodeDone = Get-Checkpoint -CheckpointName $VSCodeCheckpoint
    
    if (-not $VSCodeDone) 
    {
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
        code --install-extension WallabyJs.wallaby-vscode
        
        Set-Checkpoint -CheckpointName $VSCodeCheckpoint -CheckpointValue 1
    }    

    # install .NET Core
    #Install-WebPackage '.NET Core Cli' 'exe' '/quiet' $DownloadFolder https://go.microsoft.com/fwlink/?LinkID=798398 'DotNetCore.1.0.0.RC2-SDK.Preview1-x64.exe' # cli
}

function Install-InternetInformationServices
{
    $checkpoint = 'InternetInformationServices'
    $done = Get-Checkpoint -CheckpointName $Checkpoint
    
    if ($done) {        
        Write-BoxstarterMessage "IIS features are already installed"
        return
    }

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

    if (Test-Path env:\BoxStarter:EnableWindowsAuthFeature)
    {
        choco install IIS-WindowsAuthentication     --source windowsfeatures --limitoutput
    }

    Set-Checkpoint -CheckpointName $checkpoint -CheckpointValue 1
}

function Install-NpmPackages
{
    $checkpoint = 'NpmPackages'
    $done = Get-Checkpoint -CheckpointName $checkpoint
    
    if ($done) {
        Write-BoxstarterMessage "NPM packages are already installed"
        return
    }

    npm install -g angular-cli # angular2 cli
    npm install -g typings
    npm install -g jspm

    Set-Checkpoint -CheckpointName $checkpoint -CheckpointValue 1
}

function Install-PowerShellModules
{
    $checkpoint = 'PowerShellModules'
    $done = Get-Checkpoint -CheckpointName $checkpoint
    
    if ($done) {
        Write-BoxstarterMessage "PowerShell modules are already installed"
        return
    }

    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
    Install-Module -Name Carbon
    Install-Module -Name PowerShellHumanizer
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Untrusted'

    Set-Checkpoint -CheckpointName $checkpoint -CheckpointValue 1
}

function Set-ChocoCoreAppPins
{
    # pin apps that update themselves
    choco pin add -n=googlechrome
    choco pin add -n=Firefox
    choco pin add -n='paint.net'
}

function Set-ChocoDevAppPins
{
    # pin apps that update themselves
    choco pin add -n=visualstudiocode
    choco pin add -n=visualstudio2015community
    choco pin add -n=sourcetree
}

function Set-BaseSettings
{    
    $checkpoint = 'BaseSettings'
    $done = Get-Checkpoint -CheckpointName $Checkpoint
    
    if ($done) {
        Write-BoxstarterMessage "Base settings are already configured"
        return
    }

	Update-ExecutionPolicy -Policy Unrestricted

    $sytemDrive = Get-SystemDrive
	Set-Volume -DriveLetter $sytemDrive -NewFileSystemLabel "System"
	Set-WindowsExplorerOptions -EnableShowHiddenFilesFoldersDrives -DisableShowProtectedOSFiles -EnableShowFileExtensions -EnableShowFullPathInTitleBar
	Set-TaskbarOptions -Combine Never

    # replace command prompt with powershell in start menu and win+x
    Set-CornerNavigationOptions -EnableUsePowerShellOnWinX

    # Disable hibernate
	Start-Process 'powercfg.exe' -Verb runAs -ArgumentList '/h off'

    Set-Checkpoint -CheckpointName $checkpoint -CheckpointValue 1
}

function Set-BaseDesktopSettings
{
    Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Google\Chrome\Application\chrome.exe"
}

function Set-DevDesktopSettings
{
    Install-ChocolateyPinnedTaskBarItem "$($Boxstarter.programFiles86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.exe"

    Install-ChocolateyFileAssociation ".dll" "$env:LOCALAPPDATA\JetBrains\Installations\dotPeek05\dotPeek64.exe"
}

function Move-WindowsLibrary {
    param(
        $libraryName,
        $newPath
    )

    if(-not (Test-Path $newPath))  #idempotent
	{
        Move-LibraryDirectory -libraryName $libraryName -newPath $newPath
    }
}

function Set-RegionalSettings
{
    $checkpoint = 'RegionalSettings'
    $done = Get-Checkpoint -CheckpointName $checkpoint
    
    if ($done) {
        Write-BoxstarterMessage "Regonal settings are already configured"
        return
    }

	#http://stackoverflow.com/questions/4235243/how-to-set-timezone-using-powershell
	&"$env:windir\system32\tzutil.exe" /s "AUS Eastern Standard Time"

	Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sShortDate -Value 'dd MMM yy'
	Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sCountry -Value Australia
	Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sShortTime -Value 'hh:mm tt'
	Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sTimeFormat -Value 'hh:mm:ss tt'
	Set-ItemProperty -Path "HKCU:\Control Panel\International" -Name sLanguage -Value ENA
    
    Set-Checkpoint -CheckpointName $checkpoint -CheckpointValue 1
}

function Set-UserSettings
{
	choco install taskbar-never-combine             --limitoutput
	choco install explorer-show-all-folders         --limitoutput
	choco install explorer-expand-to-current-folder --limitoutput
}

function New-SourceCodeFolder
{
    $sourceCodeFolder = 'git'
    if (Test-Path env:\BoxStarter:SourceCodeFolder) {
        $sourceCodeFolder = $env:BoxStarter:SourceCodeFolder
    }

    if ([System.IO.Path]::IsPathRooted($sourceCodeFolder)) {
        $sourceCodePath = $sourceCodeFolder
    }
    else
    {
        $drivePath = Get-DataDrive
        $sourceCodePath = Join-Path "$drivePath`:" $sourceCodeFolder
    }

    if(-not (Test-Path $sourceCodePath)) {
        New-Item $sourceCodePath -ItemType Directory
    }
}

function New-InstallCache
{
    param
    (
        [String]
        $InstallDrive
    )

    $tempInstallFolder = Join-Path $InstallDrive "temp\install-cache"

    if(-not (Test-Path $tempInstallFolder)) {
        New-Item $tempInstallFolder -ItemType Directory
    }

    return $tempInstallFolder
}

function Update-Path
{
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

$dataDriveLetter = Get-DataDrive
$dataDrive = "$dataDriveLetter`:"
$tempInstallFolder = New-InstallCache -InstallDrive $dataDrive

Set-RegionalSettings

# SQL Server requires some KB patches before it will work, so windows update first
Write-BoxstarterMessage "Windows update..."
Install-WindowsUpdate

# disable chocolatey default confirmation behaviour (no need for --yes)
choco feature enable --name=allowGlobalConfirmation

Set-BaseSettings
Set-UserSettings

Write-BoxstarterMessage "Starting installs"

Install-CoreApps

# pin chocolatey app that self-update
Set-ChocoCoreAppPins

Set-BaseDesktopSettings

if (Test-Path env:\BoxStarter:InstallDev)
{
	Write-BoxstarterMessage "Installing dev apps"
	Install-SqlServer -InstallDrive $dataDrive
   	Install-VisualStudio -DownloadFolder $tempInstallFolder
    Install-InternetInformationServices	
    Install-CoreDevApps
	Install-DevTools  -DownloadFolder $tempInstallFolder

    # make folder for source code
    New-SourceCodeFolder

    # pin chocolatey app that self-update
    Set-ChocoDevAppPins

    Set-DevDesktopSettings
}

if (Test-Path env:\BoxStarter:InstallHome)
{
	Install-HomeApps
}

if (Get-SystemDrive -ne $dataDriveLetter)
{    
    $checkpoint = 'MoveLibraries'
    $done = Get-Checkpoint -CheckpointName $checkpoint
    
    if ($done) {
        Write-BoxstarterMessage "Libraries are already configured"
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
    
    Set-Checkpoint -CheckpointName $checkpoint -CheckpointValue 1
}

# re-enable chocolatey default confirmation behaviour
choco feature disable --name=allowGlobalConfirmation

if (Test-PendingReboot) { Invoke-Reboot }

# reload path environment variable
Update-Path

Install-NpmPackages

Install-PowerShellModules

# set HOME to user profile for git
[Environment]::SetEnvironmentVariable("HOME", $env:UserProfile, "User")

# rerun windows update after we have installed everything
Write-BoxstarterMessage "Windows update..."
Install-WindowsUpdate

Clear-Checkpoints
