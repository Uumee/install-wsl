#!/bin/pwsh
#
# install DockerImage to WSL2
#

<#
    .SYNOPSIS
    install wsl2 distribution from docker image.

	.DESCRIPTION
	1. Create Container From TargetContainerName
	2. Export Container
	3. Import WSL
	4. Execute WSL Initial Commands

	.PARAMETER ConfigFile
	json file path for configuration.

	.INPUTS
	- input your configFile

	.OUTPUTS
	- tarFile exported docker container
	- vhdxFile imported wsl
	- add wsl distribution

	.EXAMPLE
	PS> .\install-wsl.ps1

	.EXAMPLE
	PS> .\install-wsl.ps1 -ConfigFile install-wsl-rocky.json
#>

# Params #######################################

param (
	[string]$ConfigFile = "install-wsl-rocky.json"
)

# Functions #######################################

# Logging
Function Write-Log ([string]$level, [string]$message, [string]$color="White") {
	Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') ${level} ${message}" -ForegroundColor ${color}
}
Function Write-Log-Error ([string]$message) { Write-Log "ERROR" ${message} "red"}
Function Write-Log-Info  ([string]$message) { Write-Log "INFO " ${message} "yellow"}
Function Write-Log-Debug ([string]$message) { Write-Log "DEBUG" ${message} "darkgray"}

# Main #######################################

# start
Write-Log-Info  "Start Script $($MyInvocation.MyCommand.Name) ========================================"

# Arguments Debug Ountputs
Write-Log-Debug "Arguments: ConfigFile=${ConfigFile}"

# Read ConfigFile
Write-Log-Info "Start read ConfigFile"
$Config = Get-content -Path ${ConfigFile} | ConvertFrom-Json -AsHashtable
foreach( $key in $Config.keys ) {
	$msg = 'Config.{0} : {1}' -f $key, $Config[$key]
	Write-Log-Debug $msg
}
Write-Log-Info "Success read ConfigFile"
if ( $null -eq ${Config} ) {
	Write-Log-Error "Failed read ConfigFile ${ConfigFile}"
	exit 1
}

if ($(wsl -l -q) -eq $Config.WslName) {
	# Check Already Wsl Installed
	Write-Log-Error "
		CentOS-Stream-8 is Already Installed.
		Please manualy unregister wsl If You want to reinstall.
		Maybe you can following command for unregister.
		wsl --unregister $($Config.WslName)
	"
}else{

	# Create Install Wsl Home Path
	if ( -not (Test-Path $Config.InstallWslHomePath) ){
		Write-Log-Info "Create InstallWslHomePath $($Config.InstallWslHomePath)"
		New-Item -ItemType Directory -Path $Config.InstallWslHomePath
	}

	# Create WSL Distribution Path
	$wslDistPath = $Config.InstallWslHomePath + "\" + $Config.WslName
	if ( -not (Test-Path $wslDistPath) ){
		Write-Log-Info "Create WSL Distribution Path ${wslDistPath}"
		New-Item -ItemType Directory -Path $wslDistPath
	}
	
	# Create Container From TargetContainerName
	Write-Log-Info "Start create docker container from TargetContainerName"
	$alreadyDockerContainerId = $(docker container ls -aqf ("name=" + $Config.WslName))
	Write-Log-Debug "alreadyDockerContainerId: $alreadyDockercontainerId"
	if ( [string]::IsNullOrEmpty($alreadyDockerContainerId) ) {
		$cmd = "docker run --name " + $Config.WslName + " " + $Config.TargetContainerName
		Write-Log-Debug "create docker container cmd: ${cmd}"
		if ( -not $(Invoke-Expression ($cmd + ';$?')) ) {
			Write-Log-Error "Failed create docker container from TargetContainerName"
			exit 1
		}
		Write-Log-Info "Success create docker container from TargetContainerName"
	}else{
		Write-Log-Info "Already create docker container($alreadyDockerContainerId) from TargetContainerName"
	}

	# Export Container To WSLDistPath
	Write-Log-Info "Start export docker container to $wslDistPath" 
	$cmd = "docker export $($Config.WslName) -o ${wslDistPath}\$($Config.WslName).tar"
	Write-Log-Debug "export docker container cmd: ${cmd}"
	if ( -not $(Invoke-Expression ($cmd + ';$?')) ) {
		Write-Log-Error "Failed export docker container to $wslDistPath"
		exit 1
	}
	Write-Log-Info "Success export docker container to $wslDistPath"
	
	# Import WSL
	Write-Log-Info "Start WSL import"
	$cmd = "wsl --import $($Config.WslName) ${wslDistPath} ${wslDistPath}\$($Config.WslName).tar"
	Write-Log-Debug "WSL import cmd: ${cmd}"
	if ( -not $(Invoke-Expression ($cmd + ';$?')) ) {
		Write-Log-Error "Failed WSL import"
		exit 1
	}
	Write-Log-Info "Success WSL import"

	# Check Remove Container 
	$isRemoveContainer = $False
	if ( -not $Config.IsRemainContainer ){
		$isRemoveContainer = $True
	}else{
		if ( -not $Config.IsRemainImage ) {
			Write-Log-Info "
				Config.IsRemainContainer is True, but Config.IsRemainImage is False.
				No Image Container is Bad State.
				So Remove Container.
			"
			$isRemoveContainer = $True
		}
	}
	# Remove Container
	if ( $isRemoveContainer ){
		Write-Log-Info "Start remove docker container"
		$removeTargetContainerId = $(docker ps -aqf "name=$($Config.WslName)")
		$cmd = "docker container rm ${removeTargetContainerId}"
		Write-Log-Debug "remove docker container cmd: ${cmd}"
		if ( -not $(Invoke-Expression ($cmd + ';$?')) ) {
			Write-Log-Error "Failed remove docker container"
			exit 1
		}
		Write-Log-Info "Success remove docker container"
	}
	# Remove Image
	if ( -not $Config.IsRemainImage ) {
		Write-Log-Info "Start remove docker image"
		$removeTargetImageId = $(docker images -aq $Config.TargetContainerName)
		$cmd = "docker rmi ${removeTargetImageId}"
		Write-Log-Debug "remove docker image cmd: ${cmd}"
		if ( -not $(Invoke-Expression ($cmd + ';$?')) ) {
			Write-Log-Error "Failed remove docker image"
			exit 1
		}
		Write-Log-Info "Success remove docker image"
	}

	# Setting WSL Default
	if ( $Config.IsSetDefault ) {
		Write-Log-Info "Start change default wsl: $($Config.WslName)"
		$cmd = "wsl --set-default $($Config.WslName)"
		Write-Log-Debug "change default wsl: $($Config.WslName) cmd: ${cmd}"
		if ( -not $(Invoke-Expression ($cmd + ';$?')) ) {
			Write-Log-Error "Failed change default wsl: $($Config.WslName)"
			exit 1
		}
		Write-Log-Info "Success change default wsl: $($Config.WslName)"
	}

	# Execute WSL Initial Commands
	Write-Log-Info "Start initialize wsl by Config.WslInitialCommands"
	foreach ( $wslcmd in $Config.WslInitialCommands ){
		$cmd = "wsl --distribution $($Config.WslName) $wslcmd"
		Write-Log-Debug "execute cmd: $cmd"
		Invoke-Expression $cmd
	}
	Write-Log-Info "Success initialize wsl by Config.WslInitialCommands"

}

# end
Write-Log-Info  "End Script   $($MyInvocation.MyCommand.Name) ========================================"
Write-OutPut "" # NewLine at end of script
exit 0