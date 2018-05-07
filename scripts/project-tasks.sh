#!/bin/bash


# #############################################################################
# Settings
#
nugetFeedUri="https://www.myget.org/F/**ACCOUNT_NAME**/api/v2"
nugetKey=$NUGET_KEY #env variable 
nugetVersion="1.0.0"

BLUE="\033[00;94m"
GREEN="\033[00;92m"
RED="\033[00;31m"
RESTORE="\033[0m"
YELLOW="\033[00;93m"
ROOT_DIR=$(pwd)


# #############################################################################
# Kills all running containers of an image
#
clean() {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Cleaning docker images                        "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    if [[ -z $ENVIRONMENT ]]; then
        ENVIRONMENT="development"
    fi

    composeFileName="docker-compose.yml"
    if [[ $ENVIRONMENT != "" ]]; then
        composeFileName="docker-compose.$ENVIRONMENT.yml"
    fi

    if [[ ! -f $composeFileName ]]; then
        echo -e "${RED}Environment '$ENVIRONMENT' is not a valid parameter. File '$composeFileName' does not exist. ${RESTORE}\n"
    else
        docker-compose -f $composeFileName down --rmi all

        # Remove any dangling images (from previous builds)
        danglingImages=$(docker images -q --filter 'dangling=true')
        if [[ ! -z $danglingImages ]]; then
        docker rmi -f $danglingImages
        fi

        rtn=$?
        if [ "$rtn" != "0" ]; then
            echo -e "${RED}An error occurred${RESTORE}"
            exit $rtn
        fi

        echo -en "${YELLOW}Removed docker images${RESTORE}\n"
    fi
}


# #############################################################################
# Runs docker-compose
#
compose () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Composing docker images                       "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    if [[ -z $ENVIRONMENT ]]; then
        ENVIRONMENT="development"
    fi

    composeFileName="docker-compose.yml"
    if [[ $ENVIRONMENT != "development" ]]; then
        composeFileName="docker-compose.$ENVIRONMENT.yml"
    fi

    if [[ ! -f $composeFileName ]]; then
        echo -e "${RED}Environment '$ENVIRONMENT' is not a valid parameter. File '$composeFileName' does not exist. ${RESTORE}\n"
    else

        echo -e "${YELLOW}Building the image...${RESTORE}\n"
        docker-compose -f $composeFileName build

        echo -e "${YELLOW}Creating the container...${RESTORE}\n"
        docker-compose -f $composeFileName kill
        docker-compose -f $composeFileName up -d

    fi

    rtn=$?
    if [ "$rtn" != "0" ]; then
        echo -e "${RED}An error occurred${RESTORE}"
        exit $rtn
    fi
}


# #############################################################################
# Deploys nuget packages to nuget feed
#
# @1 build-environment
#
nugetPublish () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Deploying nuget packages to nuget feed        "
    echo -e "+ $nugetFeedUri                                 "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    echo -en "${YELLOW} Using Key: $nugetKey ${RESTORE}\n"

    buildEnvironment=@1

    if [[ -z buildEnvironment ]]; then
        buildEnvironment="debug"
    fi

    shopt -s nullglob # hide hidden

    cd src

    for dir in */ ; do # iterate projects
        [ -e "$dir" ] || continue

        cd $dir

        for nuspec in *.nuspec; do

            packageName=${dir::-1}
            echo -e "${YELLOW}Found nuspec for ${packageName} ${RESTORE}"

            dotnet pack \
            -c $buildEnvironment \
            --include-source \
            --include-symbols

            echo -e "${YELLOW}Publishing: ${packageName}.$nugetVersion ${RESTORE}"

            curl \
            -H 'Content-Type: application/octet-stream' \
            -H "X-NuGet-ApiKey: $nugetKey" \
            $nugetFeedUri \
            --upload-file bin/$buildEnvironment/${packageName}.$nugetVersion.nupkg

            rtn=$?
            if [ "$rtn" != "0" ]; then
                echo -e "${RED}An error occurred${RESTORE}"
                exit $rtn
            fi
            
            echo -e "${GREEN}"
            echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
            echo -e "Uploaded nuspec for ${packageName}              "
            echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
            echo -e "${RESTORE}"

        done

        cd $ROOT_DIR

    done

}


# #############################################################################
# Runs the unit tests.
#
unitTests () {

    echo -e "${GREEN}"
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "+ Running unit tests                            "
    echo -e "++++++++++++++++++++++++++++++++++++++++++++++++"
    echo -e "${RESTORE}"

    for dir in test/*UnitTests*/ ; do
        [ -e "$dir" ] || continue
        dir=${dir%*/}
        echo -e "Found tests in: test/${dir##*/}"
        cd $dir
        dotnet test 
        rtn=$?
        if [ "$rtn" != "0" ]; then
            echo -e "${RED}An error occurred${RESTORE}"
            exit $rtn
        fi
    done

}


# #############################################################################
# Shows the usage for the script
#
showUsage () {

    echo -e "${YELLOW}"
    echo -e "Usage: project-tasks.sh [COMMAND]"
    echo -e "    Orchestrates various jobs for the project"
    echo -e ""
    echo -e "Commands:"
    echo -e "    clean: Removes the images and kills all containers based on that image."
    echo -e "    compose: Runs docker-compose."
    echo -e "    composeForDebug: Builds the image and runs docker-compose."
    echo -e "    nugetPublish: Builds and packs the project and publishes to nuget feed."
    echo -e "    unitTests: Runs all unit test projects with *UnitTests* in the project name."
    echo -e ""
    echo -e "Environments:"
    echo -e "    development: Default environment."
    echo -e ""
    echo -e "Example:"
    echo -e "    ./project-tasks.sh compose debug"
    echo -e ""
    echo -e "${RESTORE}"

}


# #############################################################################
# Switch arguments
#
if [ $# -eq 0 ]; then
    showUsage
else
    ENVIRONMENT=$(echo -e $2 | tr "[:upper:]" "[:lower:]")

    case "$1" in
        "ci")
            compose
            nugetPublish
            unitTests
            ;;
        "clean")
            clean
            ;;
        "compose")
            compose
            ;;
        "composeForDebug")
            export REMOTE_DEBUGGING="enabled"
            compose
            ;;
        "nugetPublish")
            nugetPublish 
            ;;
        "unitTests")
            unitTests
            ;;
        *)
            showUsage
            ;;
    esac
fi

# #############################################################################
