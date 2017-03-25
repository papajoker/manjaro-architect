# !/bin/bash
#

ANSWER='/tmp/ma-ANSWER'

DIALOG() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

debug(){
    ((${ARGS[debug]})) && echo -e "$@" >>"$file_log"
}

# read console args , set in array ARGS global var
get_ARGS() {
    declare key param
    while [ -n "$1" ]; do
        param="$1"
        case "${param}" in
            --advanced|-a)
                ARGS[advanced]=1
                ;;
            --debug|-d)
                ARGS[debug]=1
                ;; 
            --remove|-r)
                ARGS[remove]=1
                ;;                               
            --init=*)
                key="init"
                ARGS[$key]="${param##--$key=}"
                [[ "${ARGS[$key]:0:1}" == '"' ]] && ARGS[$key]="${ARGS[$key]/\"/}" # remove quotes
                ARGS[$key]="${ARGS[$key],,}" # lowercase
                ;;
            --help|-h)
                echo "usage [-d|--debug] [-r|--remove] [ --init=openrc ] [-a|--advanced] "
                exit 0
                ;;                
            -*)
                echo "${param}: not used";
                ;;
        esac
        shift
    done
    #declare -g -r ARGS
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
        ARGS[advanced]=0
    else
        ARGS[advanced]=1
    fi
}

####################################################
#  working tests menus functions
####################################################

mnu_return(){ return "${1:-98}"; }   # return mnu -1 (done)
returnOK(){ return 0; }    # function is ok
returnNO(){ return 1; }
workfunction(){ pacman -Syu; } # generate error for test


mount_disk_and_root(){ # simulate
    INSTALL[mounted]=1
    DIALOG " OK " --msgbox "\n chroot is now ok :) \n" 0 0
    return 0
}

# tests -------------------------------------

#change item and function from param
check_menu_edit_config_begin(){
    if [[ "${ARGS[init]}" == "systemd" ]]; then
        menu_item_change "init config" "systemd configuration" "nano /etc/${ARGS[init]}/system.conf"
    else
        menu_item_change "init config"  "openrc configuration" "nano /etc/rc.conf"
    fi

    if ((ARGS[remove])); then
        menu_item_change "pacman.conf"  # no args = remove
    fi

    # tests
    menu_item_insert "pacman.conf" "test insert" "nano test_insert"
    menu_item_insert "" "last item" "nano test_add"

    return 0
}

check_menu_is_mounted(){
    if [[ "${INSTALL[mounted]}" != 1 ]]; then
        DIALOG " error " --msgbox "\n make mount in pre-install before\n" 0 0
        return "${1:-98}"
    fi
}

func_begin() { return 0; } # test in layout for exemple test if base installed
func_end() { return 0; }   # test in layout

func_exit() {   # test
    echo "func_exit $@"
    exit 0
}

# ---------- softwares

check_soft_list(){
    local i=0 item="" str=""
    for i in "${!options[@]}"; do
        if ((i % 2!=0)); then
            item="${options[$i]}"
            if [[ "${item:0:1}" != "+" ]]; then
                debug "check_soft_list: $item = ${str##* }"
                if [[ $(grep "^${str##* }$" -c "${checklist_file}") > 0 ]]; then
                    options[$i]="+${item}"
                fi
            fi
        else
            str="${functions[(($i/2))]}"
        fi
    done
    return 0
}

add_list(){
    debug "add in list: $@"
    echo "$1" >> "${checklist_file}"
    sleep 0.1
    sort -u "${checklist_file}" --output="${checklist_file}"
}