# !/bin/bash
#

ANSWER='/tmp/tmp'

DIALOG() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

debug(){
    ((${PARAMS[debug]})) && echo -e "$@" >>"../.log"
}

# read console args , set in array PARAMS global var
get_params() {
    declare key param
    while [ -n "$1" ]; do
        param="$1"
        case "${param}" in
            --advanced|-a)
                PARAMS[advanced]=1
                ;;
            --debug|-d)
                PARAMS[debug]=1
                ;;                
            --init=*)
                key="init"
                PARAMS[$key]="${param##--$key=}"
                [[ "${PARAMS[$key]:0:1}" == '"' ]] && PARAMS[$key]="${PARAMS[$key]/\"/}" # remove quotes
                PARAMS[$key]="${PARAMS[$key],,}" # lowercase
                ;;
            --help|-h)
                echo "usage [-d|--debug] [ --init=openrc ] [-a|--advanced] "
                exit 0
                ;;                
            -*)
                echo "${param}: not used";
                ;;
        esac
        shift
    done
}

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
#  working tests menus functions
####################################################

mnu_return(){
    return 9   # return mnu -1 (done)
}
returnOK(){
    return 0    # function is ok
}
workfunction(){
    pacman -Syu # generate error for test
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

    # delete item 2 for exemple
    #unset menus[4]; unset menus[3]; unset functions[1]

    #TODO
    # menu_item_change ( ID='' , callfunction='' )
    # menu_item_delete ( ID )
    # menu_item_insert ( ID_after='', caption, callfunction )
}

func_begin() { return 0; } # test in layout for exemple test if base installed
func_check() { return 0; } # test in layout
fn_end() { return 0; }     # test in layout