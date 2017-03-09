#!/usr/bin/bash
#
# load layout ans make dialogs


dialog_menu() {
    # add : --keep-tite to aif version
    dialog --keep-tite --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

#pick in .transfile
# file .trans not standard -> tinker for demo
# 2 args : keymenu , content(Title or Body or Item? or empty_value)
# tt( keymenu , content='Title' ) 
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

# reset numbers after delete/insert item
renumber_menutool() {
    local i=0 j=0
    for i in "${!menus[@]}"; do
        ((i % 2==0)) && { ((j=j+1)); menus[$i]=$j; }
        ((i=i+1))
    done
}

# trim line with ; as separator
trim_line()
{
    local i=0 str='' arrayr=()
    IFS=';' arrayr=($1)
    for i in "${!arrayr[@]}"; do
        # remove firsts space
        arrayr[$i]="${arrayr[$i]#"${arrayr[$i]%%[![:space:]]*}"}"
        # remove lasts space
        while [[ "${arrayr[$i]: -1}" == ' ' ]]; do
            arrayr[$i]=${arrayr[$i]:0:-1}
        done
    done
    echo "${arrayr[*]}"
}

# not used
split_line(){ IFS=';' arrayr=($@); }

# trim line menu layout
menu_split_line(){
    local str="$@"
    [ -z "$str" ] && exit 9
    trim_line "${str//-}"
}

# find item in dialog array by key
# menu_item_find ( key='' )
# return line number, 255 not found
menu_item_find() {
    [ -z "$1" ] && return 1
    local id=0 i=0
    for i in "${!menus[@]}"; do
        if [[ "${menus[$i]}" == "$1" ]]; then
            (( id= (i-1) /2 ))
            echo "$id" && return 0
        fi
    done
    return 1
}

# change or delete item menu
# menu_item_change ( key='' , caption='', callfunction='' )
# only param "key" -> remove item
menu_item_change() {
    #set -x
    local key="$1" id=255
    id=$(menu_item_find "$key")
    (($? != 0)) && return 1
    #[ -z "$id" ] && return 1
    if [[ "$2" == '' && "$3" == '' ]]; then
        unset functions[$id]
        functions=( "${functions[@]}" )
        (( id=(id*2) ))
        unset menus[$((id+1))]; unset menus[$id];
        menus=( "${menus[@]}" )
    else
        [ -n "$3" ] && functions[$id]="$3"
        (( id=(id*2)+1 ))
        [ -n "$2" ] && menus[$id]="$2"
    fi
}

# insert item after a key or add item to the end if not found
# menu_item_insert ( key_after='', caption, callfunction )
menu_item_insert () {
    local key="$1" id=255
    id=$(menu_item_find "$key")
    [ -z "$id" ] && id="${#functions[@]}"
    [[ "$2" == '' && "$3" == '' ]] && return 1
    (( id=id+1 ))
    functions=( "${functions[@]:0:id}" "$3" "${functions[@]:id}" )
    (( id=id*2 ))
    menus=( "${menus[@]:0:id}" "9" "$2" "${menus[@]:id}" )
}

# returned fy function load_options_menutool()
declare -A mnu_params=(
    [functions]=''
    [begin]=''
    [end]=''
)

menu_reset_mnu_params(){
    declare -g mnu_params
    mnu_params[functions]=''
    unset mnu_params[begin]
    unset mnu_params[end]
}

####################################################
# #parse file data/*.menu
# return array
####################################################
# load_options_menutool( IDmenu , template='default' )

load_options_menutool() {
    local menukey="${1:-install_environment}"
    local menuglobal_items=() menuglobal_fn=() tmp=()
    local localfilename="${2:-default}"
    local level='' levelsub='' reg loop curentitem i j
    local IFS=$'\n'
    debug "\nfind menu: $menukey"    
    menu_reset_mnu_params
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
            (("${#line[@]}">1)) && mnu_params[begin]="${line[1]}"
            (("${#line[@]}">2)) && mnu_params[end]="${line[2]}"
            debug "key:$menukey find :) ${mnu_params[@]}"
            continue
        fi
        if [ -n "$levelsub" ]; then
            reg="^$levelsub[a-zA-Z_]"
            if [[ $line =~ $reg ]]; then
                # menu item find
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
                    # prev-item load a sub menu
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
        mnu_params[functions]="${mnu_params[functions]}${i};"
    done
    for i in "${!menuglobal_items[@]}"; do
        (( j=i+1 ))
        debug "$j  \"${menuglobal_items[$i]}\" \"${menuglobal_fn[$i]}\" "
        echo "$j"
        echo "${menuglobal_items[$i]}"
    done
}

####################################################
# load one menu from template and show dialog
####################################################
# show_menu ( IDmenu='MM' )

show_menu()
{
    local cmd id menus choice keymenu errcode highlight=1 nbitems=1
    local fend functions
#    declare functions
    keymenu="${1:-MM}"

    load_options_menutool "${keymenu}">'/tmp/mnu'
    # a function to remove  the third column
    mapfile -t menus < '/tmp/mnu'
    declare -p menus &>/dev/null
    IFS=';' read -a functions <<<"${mnu_params[functions]}"
    debug "functions: ${functions[@]}"

    # call function chech  begin
    if [ -n "${mnu_params[begin]}" ]; then
        ${mnu_params[begin]} $keymenu || return 99
        renumber_menutool # if insert or delete item
    fi
    if [ -n "${mnu_params[end]}" ]; then
        fend="${mnu_params[end]}"
    fi

    (( nbitems="${#menus[@]}" /2 ))
    ((nbitems>20)) && nbitems=20 # show max 20 items

    while ((1)); do
        cmd=(dialog_menu "$(tt ${keymenu} Title)" --default-item ${highlight} --menu "$(tt ${keymenu} Body)" 0 0 )
        cmd+=( $nbitems ) # add number of items

        # run dialog options
        choice=$("${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty)
        # ?choice=eval "${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty
        choice="${choice:-0}"

        case "$choice" in
            0)  return ;;                # btn cancel
            *)  debug "\nchoice: $choice"               # debug
                [ -z "$choice" ] && continue
                id=$(( "$choice"-1 ))
                fn="${functions[$id]}"      # find attach working function to array with  3 column
                debug "call function: $fn"
                # or use eval for eval ${fn} if variables $var ? nor secure ?
                ${fn}
                errcode=$?
                debug "errcode: $errcode"
                case "$errcode" in
                    99) :   # check_before in sub_menu
                        ;;
                    98) :    # check_end in sub menu
                        ;;
                    0) :
                        ((++choice))        # go to next item if ok
                        highlight=$choice
                        ;;
                    *) :    # other errors
                        break
                        ;;
                esac
        esac

    done
    # call function check end in layout
    if [ -n "${fend}" ]; then
        ${fend} $keymenu || return 98
    fi
}
