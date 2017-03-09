#!/usr/bin/bash

# usage
# test.sh -d --init="openrc" 

# $curdir if we call by ./test.sh or bin/test/sh
curdir="$(dirname $PWD/${BASH_SOURCE[0]})" 
LIBDIR="$curdir/../lib"
DATADIR="$curdir/../data"

version='dev test'
ARCHI=$(uname -m)
file_log="$curdir/../.log"


# console and tests params
declare -A PARAMS=(
    [debug]=0
    [advanced]=0
    [desktop]=''
    [efi]=0
    [init]='systemd'
)
unset PARAMS[debug]
unset PARAMS[advanced]

source "${LIBDIR}/util.sh"
source "${LIBDIR}/menu-engine.sh"


####################################################
# RUN
####################################################

((${PARAMS[debug]})) && \
    echo "$(date +%D\ %T)">"$file_log" || \
    rm "$file_log" 2>/dev/null

set_lang            # auto load translates
get_params "$@"     # read params

#just for test read params console
((${PARAMS[advanced]})) && menu_choice

#load top menu
show_menu "MM"
