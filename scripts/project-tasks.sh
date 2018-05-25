#!/bin/bash


# #############################################################################
# Settings
#

BLUE="\033[00;94m"
GREEN="\033[00;92m"
RED="\033[00;31m"
RESTORE="\033[0m"
YELLOW="\033[00;93m"
ROOT_DIR=$(PWD)


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
        dotnet test /p:CollectCoverage=true /p:CoverletOutputFormat=lcov
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
        "unitTests")
            unitTests
            ;;
        *)
            showUsage
            ;;
    esac
fi

# #############################################################################
