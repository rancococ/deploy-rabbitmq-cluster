#!/usr/bin/env bash

##########################################################################
# tool.sh
# --bind     : bind ip address
# --unbind   : unbind ip address
##########################################################################

# set -x
set -e

# set author info
date1=`date "+%Y-%m-%d %H:%M:%S"`
date2=`date "+%Y%m%d%H%M%S"`
author="yong.ran@cdjdgm.com"

set -o noglob

# font and color 
bold=$(tput bold)
underline=$(tput sgr 0 1)
reset=$(tput sgr0)

red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
blue=$(tput setaf 4)
white=$(tput setaf 7)

# header and logging
header() { printf "\n${underline}${bold}${blue}> %s${reset}\n" "$@"; }
header2() { printf "\n${underline}${bold}${blue}>> %s${reset}\n" "$@"; }
info() { printf "${white}➜ %s${reset}\n" "$@"; }
warn() { printf "${yellow}➜ %s${reset}\n" "$@"; }
error() { printf "${red}✖ %s${reset}\n" "$@"; }
success() { printf "${green}✔ %s${reset}\n" "$@"; }
usage() { printf "\n${underline}${bold}${blue}Usage:${reset} ${blue}%s${reset}\n" "$@"; }

trap "error '******* ERROR: Something went wrong.*******'; exit 1" sigterm
trap "error '******* Caught sigint signal. Stopping...*******'; exit 2" sigint

set +o noglob

# entry base dir
pwd=`pwd`
base_dir="${pwd}"
source="$0"
while [ -h "$source" ]; do
    base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$base_dir/$source"
done
base_dir="$( cd -P "$( dirname "$source" )" && pwd )"
cd "${base_dir}"

# envirionment
if [ -r "${base_dir}/.env" ]; then
    while read line; do
        eval "$line";
    done < "${base_dir}/.env"
fi

# args flag
arg_help=
arg_bind=
arg_bind_device=
arg_unbind=
arg_unbind_device=
arg_empty=true

# parse parameter
# echo $@
# define options, -o : short options, -a : simple mode for long options (starts with -), -l : long options
# no colon after, indicating no parameter
# followed by a colon to indicate that there is a required parameter
# followed by two colons to indicate that there is an optional parameter (the optional parameter must be next to the option)
# -n information on error
# -- it is also an option. for example, to create a directory named "-f", "mkdir -- -f" will be used
# $@ take the parameter list from the command line
# args=`getopt -o ab:c:: -a -l apple,banana:,cherry:: -n "${source}" -- "$@"`
args=`getopt -o h -a -l help,bind::,unbind:: -n "${source}" -- "$@"`
# terminate the execution when there is an error in the execution of getopt
if [ $? != 0 ]; then
    error "terminating..." >&2
    exit 1
fi
# echo ${args}
# reorder parameters(The purpose of using eval is to prevent the shell command in the parameter from being extended by mistake)
eval set -- "${args}"
# handling specific options
while true
do
    case "$1" in
        -h | --help | -help)
            info "option -h|--help"
            arg_help=true
            arg_empty=false
            shift
            ;;
        --bind | -bind)
            info "option --bind argument : $2"
            arg_bind=true
            arg_empty=false
            arg_bind_device=$2
            shift 2
            ;;
        --unbind | -unbind)
            info "option --unbind argument : $2"
            arg_unbind=true
            arg_empty=false
            arg_unbind_device=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            error "internal error!"
            exit 1
            ;;
    esac
done
# display parameters other than options (parameters without options will be last)
# arg is the built-in variable of getopt. the value in arg is $@ (the parameter passed in from the command line) after processing
for arg do
   warn "$arg";
done

##########################################################################

# show usage
usage=$"`basename $0` [-h|--help] [--bind=ens33] [--unbind=ens33]
       [-h|--help]
                       show help info.
       [--bind=ens33]
                       bind ip address for device.
       [--unbind=ens33]
                       unbind ip address for device.
"

# bind ip
fun_bind_ip() {
    header "bind ip : "
    bind_device_temp=${arg_bind_device:-"${CURRENT_NODE_DEVICE}"}
    bind_address_temp=${CURRENT_NODE_ADDRESS}
    info "delete ipv4.addr ${bind_address_temp} for ${bind_device_temp}"
    nmcli connection modify "${bind_device_temp}" -ipv4.addr "${bind_address_temp}" 2>/dev/null || true
    info "add ipv4.addr ${bind_address_temp} for ${bind_device_temp}"
    nmcli connection modify "${bind_device_temp}" +ipv4.addr "${bind_address_temp}" 2>/dev/null || true
    info "restart network service"
    systemctl restart network
    info "show ip addr for ${bind_device_temp}"
    ip addr show "${bind_device_temp}"
    success "successfully binded ip"
    return 0
}

# unbind ip
fun_unbind_ip() {
    header "unbind ip : "
    bind_device_temp=${arg_bind_device:-"${CURRENT_NODE_DEVICE}"}
    bind_address_temp=${CURRENT_NODE_ADDRESS}
    info "delete ipv4.addr ${bind_address_temp} for ${bind_device_temp}"
    nmcli connection modify "${bind_device_temp}" -ipv4.addr "${bind_address_temp}" 2>/dev/null || true
    info "restart network service"
    systemctl restart network
    info "show ip addr for ${bind_device_temp}"
    ip addr show "${bind_device_temp}"
    success "successfully unbinded ip"
    return 0
}

##########################################################################

# argument is empty
if [ "x${arg_empty}" == "xtrue" ]; then
    usage "$usage";
    exit 1
fi

# show usage
if [ "x${arg_help}" == "xtrue" ]; then
    usage "$usage";
    exit 1
fi

# either bind or unbind must be entered
if [[ "x${arg_bind}" == "xfalse" && "x${arg_unbind}" == "xfalse" ]]; then
    error "either bind or unbind must be entered"
    usage "$usage";
    exit 1
fi

# cannot enter bind and unbind at the same time
if [[ "x${arg_bind}" == "xtrue" && "x${arg_unbind}" == "xtrue" ]]; then
    error "cannot enter bind and unbind at the same time"
    usage "$usage";
    exit 1
fi

# bind ip
if [ "x${arg_bind}" == "xtrue" ]; then
    fun_bind_ip;
fi

# unbind ip
if [ "x${arg_unbind}" == "xtrue" ]; then
    fun_unbind_ip;
fi

echo ""

# exit $?
