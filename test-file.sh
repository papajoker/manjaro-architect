# !/usr/bin/bash

# usage
# test.sh -a --desktop="i3"


version='dev test'
LIBDIR='./lib'
DATADIR='./data'
ARCHI=$(uname -m)
ANSWER='/tmp/tmp'

# console and tests params
declare -A PARAMS=(
    ['advanced']=0
    ['desktop']=''
    ['efi']=0
    ['lusk']=0
)


####################################################

# auto load translate
#TODO: rename *.trans by code.trans (2 portuguese?)
#      add long titre in first ligne for use in list langs
function set_lang() {
    source "${DATADIR}/translations/english.trans"
    declare f="${DATADIR}/translations/${LANG:0:5}.trans"
    if [ -f "$f" ]; then
        source "$f" # po_BR ?
    else
        declare f lg="${LANG:0:2}"
        for f in ${DATADIR}/translations/${lg}*.trans; do
            source "$f"
            break
        done
    fi
    echo -e "$_PlsWaitBody"
}


# read console args , set in PARAMS global var
get_params() {
    local key
    while [ -n "$1" ]; do
        param="$1"
        case "$param" in
            --advanced|-a)
                PARAMS[advanced]=1
                ;;
            --desktop=*)
                key="desktop"
                PARAMS[$key]="${param##--$key=}"
                [[ "${PARAMS[$key]:0:1}" == '"' ]] && PARAMS[$key]="${PARAMS[$key]/\"/}"
                PARAMS[$key]="${PARAMS[$key]^^}"
                ;;
            --help|-h)
                echo "usage [-a|--advanced] [ --desktop=i3 ] "
                exit 0
                ;;                
            -*)
                echo "$param: not used";
                ;;
        esac
        shift
    done
}

# Choose between the compact and extended installer menu
menu_choice() {
    DIALOG "$_ChMenu" --radiolist "\n\n$_ChMenuBody\n" 0 0 2 \
      "regular" "" on \
      "advanced" "" off 2>${ANSWER}
    if [[ "$(<${ANSWER})" == 'regular' ]]; then
        PARAMS[advanced]=0
    else
        PARAMS[advanced]=1
    fi
}

####################################################

#pick in .transfile
# 2 params : keymenu , content
tt() {
    local str=''
    str="_${1}Menu${2}";
    str="${!str}";
    if [ -z "$str" ]; then
        [ "$2" != "Body" ] && str="$1" || str=""
    fi
    echo "$str"
}

# reset numbers after delete/insert
renumber_menutool() {
    for i in "${!options[@]}"; do
        ((i % 3==0)) && { ((j=j+1)); options[$i]=$j; }
        ((i=i+1))
    done
}

# function to remove the menus third column
format_menutool() {
    declare -a options=("$@") i=0 j=0
    renumber_menutool
    for i in "${!options[@]}"; do
        ((j=i+1))
        ((j % 3==0)) && continue
        echo "${options[$i]}"
    done
}

declare MENUGLOBAL=''
#parse file data/*.menu
load_options_menutool() {
    local menukey="${1:-install_environment}"
    debug "\nfind menu: $menukey"
    declare -a menuglobal_items=() menuglobal_fn=() i j
    local localfilename="${2:-default}"
    local tmp=() level='' levelsub='' reg loop curentitem i j
    local IFS=$'\n'
    for line  in $(grep -v "#" "$DATADIR/${localfilename}.menu"); do
        reg="-.$menukey"
        if [[ $line =~ $reg ]]; then
            level=$(echo "$line" | grep -Eo "\-{1,}")
            levelsub="$level--";
            debug "key:$menukey find :)"
            #echo "$line : find subs: ${levelsub}XX"
            continue
        fi
        if [ -n "$levelsub" ]; then
            #echo  "$line "
            reg="^$levelsub[a-zA-Z_]"
            if [[ $line =~ $reg ]]; then
                debug "ok: $line"
                line=( "${line//-}" )
                tmp="$(echo "$line"|awk -F';' '{print $2}')"
                tmp="${tmp:-returnOK}"
                curentitem="${line//-}"
                curentitem="$(echo "$line"|awk -F';' '{print $1}')"
                curentitem=${curentitem//[[:space:]]/}
                debug "curitem: $curentitem"
                menuglobal_items+=( "$(tt $curentitem Title)" )
                menuglobal_fn+=( "${tmp//[[:space:]]/}" )
            else
                reg="^$levelsub--[a-zA-Z_]"
                if [[ $line =~ $reg ]]; then
                    # this item load a sub menu
                    #echo "sous mnu: de $line = $curentitem"
                    menuglobal_fn[-1]="show_menu $curentitem"
                    i=$(( "${#menuglobal_items[@]}"-1 ))
                    tmp="${menuglobal_items[-1]}"
                    [[ "${tmp: -1}" != ">" ]] && menuglobal_items[-1]="${tmp} |>"
                    continue
                fi
                reg="^$level[a-zA-Z_]"
                [[ $line =~ $reg ]] && break
            fi
        fi
    done

    MENUGLOBAL=''
    for i in "${menuglobal_fn[@]}"; do
        MENUGLOBAL="${MENUGLOBAL}${i};"
    done
    debug "functions: ${MENUGLOBAL}"
    debug  "-------------"
    for i in "${!menuglobal_items[@]}"; do
        (( j=i+1 ))
        debug "$j  \"${menuglobal_items[$i]}\" \"${menuglobal_fn[$i]}\" "
        echo "$j"
        echo "${menuglobal_items[$i]}"
    done
}

DIALOG() {
    # add : --keep-tite to aif version
    dialog --keep-tite --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

debug(){
    echo -e "$@" >>"./.log"
}

mnu_return(){
    return 9   # return mnu -1 (done)
}
returnOK(){
    return 0    # function is ok
}
workfunction(){
    pacman -Syu # generate a error for test
}


####################################################

show_menu()
{
    local cmd id options menus choice keymenu functions errcode highlight=1 nbitems=1
    keymenu="${1:-MM}"

    load_options_menutool "${keymenu}">'/tmp/mnu'
    # a function to remove  the third column
    mapfile -t menus < '/tmp/mnu'
    declare -p menus &>/dev/null

    debug "functions: ${MENUGLOBAL}"
    IFS=';' read -a functions <<<"${MENUGLOBAL}"
    debug "functions: ${functions[@]}"

    # call function_begin

    (( nbitems="${#menus[@]}" /2 ))
    debug "number of items: $id :menu:${menus[@]}"

    while ((1)); do
        cmd=(DIALOG "$(tt ${keymenu} Title)" --default-item ${highlight} --menu "$(tt ${keymenu} Body)" 0 0 )
        cmd+=( $nbitems ) # number of lines

        # run dialog options
        choice=$("${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty)
        choice="${choice:-0}"

        case "$choice" in
            0)  return 0 ;;                # btn cancel
            *)  debug "\nchoice: $choice"     # debug
                debug "functions: ${functions[@]}"     # debug
                [ -z "$choice" ] && continue
                id=$(( "$choice"-1 ))
                fn="${functions[$id]}"      # find attach working function to array with  3 column
                #echo ::${fn}::                  # debug
                debug "\ncall function: $fn"
                eval "${fn}" #|| return $? # run working(or submenu) function
                errcode=$?
                debug "errcode: $errcode"
                if ((errcode!=0)); then
                    break
                else
                    ((++choice))
                    highlight=$choice
                fi
        esac

    done
    # call function_end
}

[ -f "./.log" ] && echo "">"./.log"
set_lang            # auto load translates
get_params "$@"     # read params

if [[ "${PARAMS[advanced]}" == '0' ]]; then
    menu_choice
fi

show_menu "MM"
