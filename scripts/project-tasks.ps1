<#
.SYNOPSIS
	Orchestrates docker containers.
.PARAMETER Clean
	Removes the image and kills all containers based on that image.
.PARAMETER Compose
	Builds and runs a Docker image.
.PARAMETER ComposeForDebug
	Builds and debugs a Docker image.
.PARAMETER Environment
	The environment to compose, defaults to development (docker-compose.yml)
.EXAMPLE
	C:\PS> .\project-tasks.ps1 -Compose -Environment Integration 
#>

# #############################################################################
# Params
#
[CmdletBinding(PositionalBinding = $false)]
Param(
    [switch]$Clean,
    [switch]$Compose,
    [switch]$ComposeForDebug,
    [ValidateNotNullOrEmpty()]
    [String]$Environment = "development"
)


# #############################################################################
# Settings
#
$Environment = $Environment.ToLowerInvariant()


# #############################################################################
# Kills all running containers of an image
#
Function CleanAll () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Cleaning projects and docker images           " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    dotnet clean
    
    $composeFileName = "docker-compose.yml"
    If ($Environment -ne "development") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    If (Test-Path $composeFileName) {
        docker-compose -f "$composeFileName" -p $ProjectName down --rmi all

        $danglingImages = $(docker images -q --filter 'dangling=true')
        If (-not [String]::IsNullOrWhiteSpace($danglingImages)) {
            docker rmi -f $danglingImages
        }
        Write-Host "Removed docker images" -ForegroundColor "Yellow"
    }
    else {
        Write-Error -Message "Environment '$Environment' is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}


# #############################################################################
# Compose docker images
#
Function Compose () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Composing docker images                       " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    $composeFileName = "docker-compose.yml"
    If ($Environment -ne "development") {
        $composeFileName = "docker-compose.$Environment.yml"
    }

    If (Test-Path $composeFileName) {

        Write-Host "Building the image..." -ForegroundColor "Yellow"
        docker-compose -f "$composeFileName" build

        Write-Host "Creating the container..." -ForegroundColor "Yellow"
        docker-compose -f $composeFileName kill
        docker-compose -f $composeFileName up -d
    }
    else {
        Write-Error -Message "Environment '$Environment' is not a valid parameter. File '$composeFileName' does not exist." -Category InvalidArgument
    }
}


# #############################################################################
# Switch arguments
#
If ($Clean) {
    CleanAll
}
ElseIf ($Compose) {
    Compose
}
ElseIf ($ComposeForDebug) {
    $env:REMOTE_DEBUGGING = "enabled"
    Compose
}


# #############################################################################
