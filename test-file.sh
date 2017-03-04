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

declare -g -A MENUGLOBAL
#parse file data/*.menu
load_options_menutool() {
    local menukey="${1:-install_environment}"
    MENUGLOBAL[key]="$menukey"
    declare -a menuglobal_items=() menuglobal_fn=()
    local localfilename="${2:-default}"
    local tmp=() level='' levelsub='' reg loop curentitem i j
    local IFS=$'\n'
    for line  in $(grep -v "#" "$DATADIR/${localfilename}.menu"); do
        reg="-.$menukey"
        if [[ $line =~ $reg ]]; then
            level=$(echo "$line" | grep -Eo "\-{1,}")
            levelsub="$level--";
            echo "key:$menukey"
            echo "$line : find subs: ${levelsub}XX"
            continue
        fi
        if [ -n "$levelsub" ]; then
            #echo  "$line "
            reg="^$levelsub[a-zA-Z_]"
            if [[ $line =~ $reg ]]; then
                echo "ok: $line"
                line=( "${line//-}" )
                tmp="$(echo "$line"|awk '{print $2}')"
                tmp="${tmp:-returnOK}"
                curentitem="${line//-}"
                menuglobal_items+=( $(echo "$line"|awk '{print $1}') )
                menuglobal_fn+=( "$tmp" )
            else
                reg="^$levelsub--[a-zA-Z_]"
                [[ $line =~ $reg ]] && {
                    # this item load a sub menu
                    echo "sous mnu: de $line = $curentitem"
                    menuglobal_fn[$((${#menuglobal_fn[@]}-1))]="show menu $curentitem"
                    continue
                }
                reg="^$level[a-zA-Z_]"
                [[ $line =~ $reg ]] && break
            fi
        fi
    done
    MENUGLOBAL[items]="${menuglobal_items[@]}"
    MENUGLOBAL[fn]="${menuglobal_fn[@]}"
    echo  "-------------"
    for i in "${!menuglobal_items[@]}"; do
        (( j=i+1 ))
        echo "$j  \"${menuglobal_items[$i]}\" \"${menuglobal_fn[$i]}\" "
    done
 
}

DIALOG() {
    # add : --keep-tite to aif version
    dialog --keep-tite --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}


####################################################

main_menu()
{
    local cmd id options menus choice loopmenu keymenu
    keymenu="$1:-main_menu"
    cmd=(DIALOG "$_keymenu" --menu "$_keymenu_present" 0 0 )

    load_options_menutool "$_keymenu"
    #options=load_options_menutool "$_keymenu"

    # a function to remove  the third column
    mapfile -t menus <<< "$(format_menutool "${options[@]}" )"
    declare -p menus &>/dev/null

    (( id="${#options[@]}" /3 ))
    cmd+=( $id ) # number of lines
exit
    loopmenu=1
    while ((1)); do

        # run dialog options
        choice=$("${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty)
        choice="${choice:-0}"

        case "$choice" in
            0) return 0 ;;                # btn cancel
            *)  echo "$choice"            # debug
                id=$(( (choice*3)-1 ))
                fn="${options[$id]}"      # find attach working function to array with  3 column
                echo $fn                  # debug
                $fn # run working(or submenu) function
        esac

    done
}

set_lang            # auto load translates
get_params "$@"     # read params

if [[ "${PARAMS[advanced]}" == '0' ]]; then
    menu_choice
fi

main_menu 
