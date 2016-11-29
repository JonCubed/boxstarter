# Automated Windows PC Setup

A script for setting up a Windows PC using BoxStarter and Chocolatey.

This script is based on my original [gist](https://gist.github.com/JonCubed/e5f6c273b6e836a8cfba0a92fe2f4f1a)
and [neutmute script's](https://github.com/neutmute/nm-boxstarter)

## How To Use

There are a few options for launching a BoxStarter script check out the [offical documentation](http://boxstarter.org/InstallingPackages) for
all the various methods. We'll focus on two methods - manual and bootstrapper.

### Bootstrapper

The Bootstrapper method is the recommended way to run this script. Simply open a evelated powershell
console and run the following command

```powershell
> wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" <arguments> }
```

You can remove *&lt;arguments&gt;* or replace it with one or more argument lists below

|Argument|Type|Requires|Value Description|
|--------|----|--------|-----------------|
|InstallDev|Switch||Configures machine for development and install development apps|
|InstallHome|Switch||Configures machine for home and install home apps|
|SkipWindowsUpdate|Switch||Skips running windows update|
|DataDrive|Char||Drive letter to move data too. Defaults to System Drive|
|SourceCodeFolder|String|InstallDev|Relative or Absolute path to source code folder. If relative will use Data Drive value|
|EnableWindowsAuthFeature|Switch|InstallDev|Enable Windows Authentication in IIS|
|SqlServer2016IsoImage|String|InstallDev|Absolute path to Sql Server 2016 ISO|
|SqlServer2014IsoImage|String|InstallDev|Absolute path to Sql Server 2014 ISO|

#### Examples

1. Setup a development box without windows update

```powershell
> wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" -InstallDev -SkipWindowsUpdate }
```

1. Setup a development box, move windows libraries and source code folder to another drive

```powershell
> wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" -InstallDev -DataDrive 'D' -SourceCodeFolder '/source' }
```

1. Setup a development box with sql server 2016

```powershell
> wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" -InstallDev -SqlServer2016IsoImage 'D:/temp/en_sql_server_2016_developer_x64_dvd_8777069.iso' }
```

1. Setup a development box with sql server 2014

```powershell
> wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" -InstallDev -SqlServer2014IsoImage 'D:/temp/en_sql_server_2014_developer_x64_dvd_8777069.iso' }
```

1. Setup a home box

```powershell
> wget -Uri 'https://raw.githubusercontent.com/JonCubed/boxstarter/master/bootstrap.ps1' -OutFile "$($env:temp)\bootstrap.ps1";&Invoke-Command -ScriptBlock { &"$($env:temp)\bootstrap.ps1" -InstallHome }
```


### Manual

If you want more control over what is happening you can manually run the script.

1. You must first setup environment keys for the features you would like to install.

    |Key|Value|Requires|Value Description|
    |--------|----|--------|-----------------|
    |BoxStarter:InstallDev|1||Configures machine for development and install development apps|
    |BoxStarter:InstallHome|1||Configures machine for home and install home apps|
    |BoxStarter:SkipWindowsUpdate|1||Skips running windows update|
    |BoxStarter:DataDrive|Char||Drive letter to move data too. Defaults to System Drive|
    |BoxStarter:SourceCodeFolder|String|BoxStarter:InstallDev|Relative or Absolute path to source code folder. If relative will use Data Drive value|
    |BoxStarter:EnableWindowsAuthFeature|1|BoxStarter:InstallDev|Enable Windows Authentication in IIS|
    |choco:sqlserver2016:isoImage|String|BoxStarter:InstallDev|Absolute path to Sql Server 2016 ISO|
    |choco:sqlserver2014:isoImage|String|BoxStarter:InstallDev|Absolute path to Sql Server 2014 ISO|

    > Environment variables must be added to *Machine* and *Process* scopes

1. Run the following command

    * In Command prompt or Powershell

    ```powershell
    > START http://boxstarter.org/package/nr/url?http://boxstarter.org/package/nr/url?https://raw.githubusercontent.com/JonCubed/boxstarter/master/box.ps1
    ```

  * In Edge Or Internet Explorer, go to

    ```http
    http://boxstarter.org/package/nr/url?http://boxstarter.org/package/nr/url?https://raw.githubusercontent.com/JonCubed/boxstarter/master/box.ps1
    ```
