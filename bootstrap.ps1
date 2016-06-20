#iex (((new-object net.webclient).DownloadString('https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1')) -InstallDev -SourceCodeFolder '/git' -SkipWindowsUpdate)

param 
(
    [Switch]
    $InstallDev = $false,

    [Switch]
    $InstallHome = $false,

    [String]
    $DataDrive,

    [String]
    $SourceCodeFolder,
    
    [Switch]
    $SkipWindowsUpdate,
    
    [Switch]
    $EnableWindowsAuthFeature,

    [String]
    $SqlServer2008IsoImage,

    [String]
    $SqlServer2012IsoImage,

    [String]
    $SqlServer2016IsoImage
)

function Set-EnvironmentVariable
{
    param 
    (
        [String]
        [Parameter(Mandatory=$true)]
        $Key,
        
        [String]
        [Parameter(Mandatory=$true)]
        $Value,
    )
    
    [Environment]::SetEnvironmentVariable($Key, $Value, "Machine") # for reboots
	[Environment]::SetEnvironmentVariable($Key, $Value, "Process") # for right now

}

if ($InstallDev) 
{
    Set-EnvironmentVariable -Key "BoxStarter:InstallDev" -Value "1"
}

if ($InstallHome) 
{
    Set-EnvironmentVariable -Key "BoxStarter:InstallHome" -Value "1"
}

if ($DataDrive)
{
    Set-EnvironmentVariable -Key "BoxStarter:DataDrive" -Value $DataDrive
}

if ($SourceCodeFolder)
{
    Set-EnvironmentVariable -Key "BoxStarter:SourceCodeFolder" -Value $SourceCodeFolder
}

if ($SkipWindowsUpdate)
{
    Set-EnvironmentVariable -Key "BoxStarter:SkipWindowsUpdate" -Value "1"
}

if ($EnableWindowsAuthFeature)
{
    Set-EnvironmentVariable -Key "BoxStarter:EnableWindowsAuthFeature" -Value "1"
}

if ($SqlServer2008IsoImage)
{
    Set-EnvironmentVariable -Key "choco:sqlserver2008:isoImage" -Value $SqlServer2008IsoImage
}

if ($SqlServer2012IsoImage)
{
    Set-EnvironmentVariable -Key "choco:sqlserver2012:isoImage" -Value $SqlServer2012IsoImage
}

if ($SqlServer2016IsoImage)
{
    Set-EnvironmentVariable -Key "choco:sqlserver2016:isoImage" -Value $SqlServer2016IsoImage
}

$installScript = 'http://boxstarter.org/package/nr/url?https://raw.githubusercontent.com/JonCubed/boxstarter/master/box.ps1'
$edgeVersion = Get-AppxPackage -Name Microsoft.MicrosoftEdge 

if ($edgeVersion)
{ 
    start microsoft-edge:$installScript
}
else
{
    $IE=new-object -com internetexplorer.application
    $IE.navigate2($installScript)
    $IE.visible=$true
}
