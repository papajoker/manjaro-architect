#!/usr/bin/bash
#set -x
# usage
# test.sh -d --init="openrc" 

# $curdir if we call by ./test.sh or bin/test/sh
curdir="$(dirname $PWD/${BASH_SOURCE[0]})" 
LIBDIR="$curdir/../lib"
DATADIR="$curdir/../data"

version='dev test'
ARCHI=$(uname -m)
file_log="$curdir/../.log"


# console and tests ARGS
declare -A ARGS=(
    [debug]=0
    [advanced]=0
    [desktop]=''
    [efi]=0
    [init]='systemd'
)
unset ARGS[debug]
unset ARGS[advanced]
unset ARGS[remove]        # test: remove item config item "pacman.conf"

# checks install
# for refuse a menu entry
# for delete/rewrite items
declare -A INSTALL=(
    [mounted]=0
    [mirroelist]=0
    [pacmankeys]=0
    [fstab]=0
    [hostname]=0
    [locale]=0
    [keymap]=0
    [root]=0
    [user]=0
    [gpudriver]=0
    [networkdriver]=0
    [linux]=0
    [dm]=0
    [de]=0
    [init]=0
)

source "${LIBDIR}/util.sh"
source "${LIBDIR}/menu-engine.sh"


####################################################
# RUN
####################################################

if ((${ARGS[debug]})); then
    echo "$(date +%D\ %T)">"$file_log"
else
    rm "$file_log" 2>/dev/null
fi

set_lang            # auto load translates
get_ARGS "$@"     # read ARGS

#just for test read ARGS console
((${ARGS[advanced]})) && menu_choice

#load top menu
show_menu "MM"
