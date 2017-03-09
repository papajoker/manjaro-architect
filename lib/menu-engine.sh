#!/usr/bin/bash
#
# load layout ans make dialogs


dialog_menu() {
    # add : --keep-tite to aif version
    dialog --keep-tite --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

#pick in .transfile
# file .trans not standard -> tinker for demo
# 2 params : keymenu , content(Title or Body or Item? or empty_value)
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
    menu_reset_params
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
            (("${#line[@]}">1)) && MENUPARAMS[begin]="${line[1]}"
            (("${#line[@]}">2)) && MENUPARAMS[end]="${line[2]}"
            debug "key:$menukey find :) ${MENUPARAMS[@]}"
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
        MENUPARAMS[functions]="${MENUPARAMS[functions]}${i};"
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
    local functions fend
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
        renumber_menutool # if insert or delete item
    fi
    if [ -n "${MENUPARAMS[end]}" ]; then
        fend="${MENUPARAMS[end]}"
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
            0)  return 0 ;;                # btn cancel
            *)  debug "\nchoice: $choice"               # debug
                debug "functions: ${functions[@]}"      # debug
                [ -z "$choice" ] && continue
                id=$(( "$choice"-1 ))
                fn="${functions[$id]}"      # find attach working function to array with  3 column
                debug "\ncall function: $fn"
                ${fn} #|| return $? # run working(or submenu) function
                errcode=$?
                debug "errcode: $errcode"
                if ((errcode!=0)); then
                    break
                else
                    ((++choice))        # go to next item if ok
                    highlight=$choice
                fi
        esac

    done
    # call function check end in layout
    if [ -n "${fend}" ]; then
        ${fend} $keymenu || return 100
    fi
}
