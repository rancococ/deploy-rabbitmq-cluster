#!/usr/bin/env bash

##########################################################################
# cluster.sh
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
arg_init=
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
args=`getopt -o h -a -l help,init -n "${source}" -- "$@"`
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
        --init | -init)
            info "option --init"
            arg_init=true
            arg_empty=false
            shift
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
usage=$"`basename $0` [-h|--help] [--init]
       [-h|--help]
                       show help info.
       [--init]
                       init cluster.
"

# init cluster
fun_init_cluster() {
    header "init cluster : "

    info "wait for rabbitmq"
    for i in {30..0}; do
        flag=$(docker exec -it rabbitmq_cluster rabbitmqctl ping | grep succeeded | wc -l || true)
        if [[ ${flag} > 0 ]]; then
            echo 'ok'
            break
        fi
        echo "rabbitmq is starting, countdown [${i}] ..."
        sleep 1
    done
    if [[ $i = 0 ]]; then
        echo >&2 "rabbitmq start failed."
        exit 1
    fi

    info "rabbitmqctl stop_app"
    docker exec -it rabbitmq_cluster rabbitmqctl stop_app
    info "rabbitmqctl reset"
    docker exec -it rabbitmq_cluster rabbitmqctl reset
    info "rabbitmqctl start_app"
    docker exec -it rabbitmq_cluster rabbitmqctl start_app
    info "rabbitmqctl set_policy"
    docker exec -it rabbitmq_cluster rabbitmqctl set_policy -p / ha-all "^" '{"ha-mode":"all","ha-sync-mode":"automatic","ha-promote-on-shutdown":"always","ha-promote-on-failure":"always"}'

    success "successfully initialized cluster"
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

# init cluster
if [ "x${arg_init}" == "xtrue" ]; then
    fun_init_cluster;
fi

echo ""

# exit $?
