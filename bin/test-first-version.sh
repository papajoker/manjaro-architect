# !/usr/bin/bash

# usage
# test.sh -a --desktop="i3"


version='dev test'
LIBDIR='../lib'
DATADIR='../data'
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

DIALOG() {
    # add : --keep-tite to aif version
    dialog --keep-tite --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

donefn() {
    exit 0
}


####################################################

# modify item desktop , text and function
# delete item if not advanced
sub_menu()
{
    local cmd id options menus choice loopmenu
    cmd=(DIALOG "content set by params" --menu "test.sh [--desktop=i3] [-a]" 0 0 )
    options=(
       1 "Option 1" mount_partitions  # number 3 is the function
       2 "Install desktop" install_desktop
       3 "Option 3 | >" sub_menu_extra
       4 "Option for advanced user" function_extra
       5 "nothing" get_params
    )

    # somes tests
    # can replace item 3 ...
    if [[ "${PARAMS[desktop]}" != '' ]]; then
        options[4]="install ${PARAMS[desktop]}"
        options[5]="install_desktop_${PARAMS[desktop]}" # change call
    fi
    # can delete item from parameters/hardware/...
    if [[ "${PARAMS[advanced]}" == '0' ]]; then
        unset options[11]   # delete line 4
        unset options[10]
        unset options[9]
    fi  
    # end tests

    if ((${#options[@]}==0)); then
        # if menu empty run a working function
        format_and_install ; return $?
    fi

    (( id="${#options[@]}" /3 ))
    cmd+=( $id ) # number of lines

    # a function to remove  the third column
    mapfile -t menus <<< "$(format_menutool "${options[@]}" )"
    declare -p menus &>/dev/null

    loopmenu=1
    while ((loopmenu)); do

        # run dialog options
        choice=$("${cmd[@]}" "${menus[@]}" 2>&1 >/dev/tty)
        choice="${choice:-0}"

        case "$choice" in
            0) return 0 ;;                # btn cancel
            *)  
                id=$(( (choice*3)-1 ))
                fn="${options[$id]}"      # find attach working function to array with  3 column
                echo $fn                  # debug
                $fn &>/dev/null || return $?        # run working(or submenu) function
        esac

    done
}

# just use array from advanced or not
main_menu()
{
    local cmd id options menus choice loopmenu
    cmd=(DIALOG "view a sub menu" --menu "test.sh [--desktop=i3] [-a]" 0 0 )
    options=(
        1 "$_PrepMenuTitle |>" sub_menu  # number 3 is the function
        2 "$_InstBsMenuTitle |>" sub_menu
        3 "$_InstGrMenuTitle |>" sub_menu
        4 "$_ConfBseMenuTitle |>" sub_menu
        5 "$_SeeConfOptTitle |>" sub_menu
        6 "$_Done" donefn
    )
    if [[ "${PARAMS[advanced]}" == '1' ]]; then
      options=(
        1 "$_PrepMenuTitle |>" sub_menu  # number 3 is the function
        5 "$_InstBsMenuTitle |>" sub_menu
        8 "$_InstGrMenuTitle |>" sub_menu
        9 "$_ConfBseMenuTitle |>" sub_menu
        9 "$_InstNMMenuTitle |>" sub_menu
        9 "$_InstMultMenuTitle |>" sub_menu       
        9 "$_SecMenuTitle |>" sub_menu
        2 "$_SeeConfOptTitle |>" sub_menu
        2 "$_Done" exit        
      )
    fi      

    (( id="${#options[@]}" /3 ))
    cmd+=( $id ) # number of lines

    # a function to remove  the third column
    mapfile -t menus <<< "$(format_menutool "${options[@]}" )"
    declare -p menus &>/dev/null

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