#!/usr/bin/bash

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
    ['init']='systemd'
)


####################################################

# auto load translate
#TODO: rename *.trans by code.trans (2 portuguese?)
#      add long titre in first ligne for use in list langs choises
function set_lang() {
    source "${DATADIR}/translations/english.trans"
    declare f="${DATADIR}/translations/${LANG:0:5}.trans"
    if [ -f "$f" ]; then
        source "$f" # po_BR.trans exist ?
    else
        declare f lg="${LANG:0:2}"
        for f in ${DATADIR}/translations/${lg}*.trans; do
            source "$f" # po.trans exist ?
            break
        done
    fi
    echo -e "$_PlsWaitBody" # for control
}


# read console args , set in array PARAMS global var
get_params() {
    local key
    while [ -n "$1" ]; do
        param="$1"
        case "$param" in
            --advanced|-a)
                PARAMS[advanced]=1
                ;;
            --init=*)
                key="init"
                PARAMS[$key]="${param##--$key=}"
                [[ "${PARAMS[$key]:0:1}" == '"' ]] && PARAMS[$key]="${PARAMS[$key]/\"/}"
                PARAMS[$key]="${PARAMS[$key]^^}"
                ;;
            --help|-h)
                echo "usage [-a|--advanced] [ --init=openrc ] "
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
# file .trans not standard -> tinker for demo
# 2 params : keymenu , content(Title or Body or Item? or empty_value)
tt() {
    local str="" content="${2:-Title}"
    str="_${1}Menu${content}"
    if [ ! -v "$str" ]; then # var not exist ?
        str="_${1}${content}"
    fi
    if [ ! -v "$str" ]; then # var exist ?
        [ "$2" != "Body" ] && str="$1" || str=""
    else
        str="${!str}"
        if [ -z "$str" ]; then # error in .trans ?
            [ "$2" != "Body" ] && str="$1" || str=""
        fi
    fi
    echo "$str"
}

# reset numbers after delete/insert, not used
renumber_menutool() {
    for i in "${!options[@]}"; do
        ((i % 3==0)) && { ((j=j+1)); options[$i]=$j; }
        ((i=i+1))
    done
}

# trim line menu layout
trim_line()
{
    local i=0 str='' arrayr=()
    IFS=';' arrayr=($1)
    for i in "${!arrayr[@]}"; do
        # remove firsts space
        arrayr[$i]="${arrayr[$i]#"${arrayr[$i]%%[![:space:]]*}"}"
        # remove lasts
        while [[ "${arrayr[$i]: -1}" == ' ' ]]; do
            arrayr[$i]=${arrayr[$i]:0:-1}
        done
    done
    echo "${arrayr[*]}"
}

# not used
split_line(){
    IFS=';' arrayr=($@)
}

menu_split_line(){
    local str="$@"
    [ -z "$str" ] && exit 9
    trim_line "${str//-}"
}

# returned fy function load_options_menutool()
declare -A MENUPARAMS=(
    [functions]=''
    [begin]=''
    [end]=''
)

menu_reset_params(){
    declare -g MENUPARAMS
    MENUPARAMS[functions]=''
    unset MENUPARAMS[begin]
    unset MENUPARAMS[end]
}

#parse file data/*.menu
load_options_menutool() {
    local menukey="${1:-install_environment}"
    declare -a menuglobal_items=() menuglobal_fn=() tmp=()
    local localfilename="${2:-default}"
    local level='' levelsub='' reg loop curentitem i j
    local IFS=$'\n'
    debug "\nfind menu: $menukey"    
    menu_reset_params
    debug "functions raz: ${MENUPARAMS[functions]}"
    for line  in $(grep -v "#" "$DATADIR/${localfilename}.menu"); do
        #reg="-.$menukey^[a-zA-Z_;]" #[^a-zA-Z_]"
        reg="-.${menukey}([ ;]|$)"
        if [[ $line =~ $reg ]]; then
            # menu find
            level=$(echo "$line" | grep -Eo "\-{1,}")
            levelsub="$level--";
            # functions check before and after loop
            line=$(menu_split_line "$line")
            IFS=';' line=($line)
            debug "menu find: ${line[@]} \n nb cols:${#line[@]}"
            (("${#line[@]}">1)) && MENUPARAMS[begin]="${line[1]}"
            (("${#line[@]}">2)) && MENUPARAMS[end]="${line[2]}"
            debug "key:$menukey find :) ${MENUPARAMS[@]}"
            continue
        fi
        if [ -n "$levelsub" ]; then
            reg="^$levelsub[a-zA-Z_]"
            if [[ $line =~ $reg ]]; then
                # menu item find
                #debug "ok, line       : $line"
                line=$(menu_split_line "$line")
                IFS=';' line=($line)
                #debug "ok, line parsed: $line"
                IFS=$';\n' line=(${line[*]})
                curentitem="${line[0]}"
                
                debug "curitem: $curentitem , function: ${line[1]} "
                menuglobal_items+=( "$(tt $curentitem Title)" )
                # attach function to item
                tmp="${line[1]}"
                tmp="${tmp:-returnOK}" # for this test
                menuglobal_fn+=( "${tmp}" )
            else
                reg="^$levelsub--[a-zA-Z_]"
                if [[ $line =~ $reg ]]; then
                    # this item load a sub menu
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

    # save function for each items
    for i in "${menuglobal_fn[@]}"; do
        MENUPARAMS[functions]="${MENUPARAMS[functions]}${i};"
    done
    debug "functions: ${MENUPARAMS[functions]}"
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

#test
#change item and function from param
check_menu_edit_config_begin(){
    menus[1]="${PARAMS[init]} config"    
    if [[ "${PARAMS[init]}" == "systemd" ]]; then
        functions[0]="nano /etc/${PARAMS[init]}/system.conf"
    else
        functions[0]="nano /etc/rc.conf"
    fi
}
func_begin() { return 0; } # test in layout for exemple test if base installed
func_check() { return 0; } # test in layout
fn_end() { return 0; }     # test in layout


####################################################

show_menu()
{
    local cmd id menus choice keymenu errcode highlight=1 nbitems=1
    local functions fbegin fend
    keymenu="${1:-MM}"

    load_options_menutool "${keymenu}">'/tmp/mnu'
    # a function to remove  the third column
    mapfile -t menus < '/tmp/mnu'
    declare -p menus &>/dev/null

    IFS=';' read -a functions <<<"${MENUPARAMS[functions]}"
    debug "functions: ${functions[@]}"

    # call function chech  begin
    if [ -n "${MENUPARAMS[begin]}" ]; then
        ${MENUPARAMS[begin]} $keymenu || return 99
    fi
    if [ -n "${MENUPARAMS[end]}" ]; then
        fend="${MENUPARAMS[end]}"
    fi    

    (( nbitems="${#menus[@]}" /2 ))
    debug "number of items: $id :menu:${menus[@]}"
    ((nbitems>20)) && nbitems=20 # show max 20 items

    while ((1)); do
        cmd=(DIALOG "$(tt ${keymenu} Title)" --default-item ${highlight} --menu "$(tt ${keymenu} Body)" 0 0 )
        cmd+=( $nbitems ) # number of lines

        # run dialog options
        choice=$("${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty)
        # ?choice=eval "${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty
        choice="${choice:-0}"

        case "$choice" in
            0)  return 0 ;;                # btn cancel
            *)  debug "\nchoice: $choice"     # debug
                debug "functions: ${functions[@]}"     # debug
                [ -z "$choice" ] && continue
                id=$(( "$choice"-1 ))
                fn="${functions[$id]}"      # find attach working function to array with  3 column
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
    # call function check end in layout
    if [ -n "${fend}" ]; then
        "${fend} $keymenu" || return 100
    fi
}

#[ -f "./.log" ] && 
echo "$(date +%D\ %T)">"./.log"
set_lang            # auto load translates
get_params "$@"     # read params

if [[ "${PARAMS[advanced]}" == '0' ]]; then
    menu_choice
fi

show_menu "MM"
