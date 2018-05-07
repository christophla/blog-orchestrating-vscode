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
.PARAMETER NuGetPublish
	Packs and deploys the NuGet projects (.nuspec)
.PARAMETER UnitTests
	Builds the image and runs the unit tests.
.EXAMPLE
	C:\PS> .\project-tasks.ps1 -Compose -Environment Integration 
#>

# #############################################################################
# Params
#
[CmdletBinding(PositionalBinding = $false)]
Param(
    [Switch]$Clean,
    [Switch]$Compose,
    [Switch]$ComposeForDebug,
    [Switch]$NuGetPublish,
    [Switch]$UnitTests,
    [ValidateNotNullOrEmpty()]
    [String]$Environment = "development"
)


# #############################################################################
# Settings
#
$Environment = $Environment.ToLowerInvariant()
$NugetFeedUri="https://www.myget.org/F/**ACCOUNT_NAME**/api/v2"
$NugetKey = $env:NUGET_KEY
$NugetVersion = "1.0.0"
$WORKING_DIR = (Get-Item -Path ".\" -Verbose).FullName

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
# Deploys nuget packages to myget feed
#
Function NuGetPublish () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Deploying nuget packages to myget feed        " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location src

    Get-ChildItem -Filter "*.nuspec" -Recurse -Depth 1 |
        ForEach-Object {

        $packageName = $_.BaseName
        Set-Location $_.BaseName

        dotnet pack `
            -c $Environment `
            --include-source `
            --include-symbols

        Write-Host "Publishing: $packageName.$NugetVersion" -ForegroundColor "Yellow"

        Invoke-WebRequest `
            -uri $NugetFeedUri `
            -InFile "bin/$Environment/$packageName.$NugetVersion.nupkg" `
            -Headers @{"X-nuget-ApiKey" = "$NugetKey"} `
            -Method "PUT" `
            -ContentType "multipart/form-data"

        Set-Location ..
    }

}

# #############################################################################
# Runs the unit tests
#
Function UnitTests () {

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Running unit tests                            " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location test

    Get-ChildItem -Directory -Filter "*UnitTests*" |
        ForEach-Object {
        
        Write-Host ""
        Write-Host "Found tests in: $_" -ForegroundColor "Blue"
        Set-Location $_.FullName       
        dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=lcov

        # replace all occurances of 'c:\' with unix-like '\' (gulp html report bug)
        (Get-Content "coverage.info") | 
            Foreach-Object {$_ -replace 'SF:C:','SF:'}  | 
                Out-File "coverage.info" -Encoding utf8

        Set-Location ..
    }

    Set-Location $WORKING_DIR

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Yellow"
    Write-Host "+ Generating code-coverage report               " -ForegroundColor "Yellow"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Yellow"

    gulp generate-coverage-report

    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"
    Write-Host "+ Report generated at:                          " -ForegroundColor "Green"
    Write-Host "+                                               " -ForegroundColor "Green"
    Write-Host "+ ${ROOT_DIR}/.coverage/index.html              " -ForegroundColor "Green"
    Write-Host "++++++++++++++++++++++++++++++++++++++++++++++++" -ForegroundColor "Green"

    Set-Location $WORKING_DIR
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
ElseIf ($UnitTests) {
    UnitTests
}


# #############################################################################
