#compdef docker
#
# zsh completion for docker (http://docker.com)
#
# version:  0.3.0
# github:   https://github.com/felixr/docker-zsh-completion
#
# contributors:
#   - Felix Riedel
#   - Steve Durrheimer
#   - Vincent Bernat
#
# license:
#
# Copyright (c) 2013, Felix Riedel
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the <organization> nor the
#       names of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Short-option stacking can be disabled with:
#  zstyle ':completion:*:*:docker:*' option-stacking no
#  zstyle ':completion:*:*:docker-*:*' option-stacking no
__docker_arguments() {
    if zstyle -T ":completion:${curcontext}:" option-stacking; then
        print -- -s
    fi
}

__docker_get_containers() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    local kind type line s
    declare -a running stopped lines args names

    kind=$1; shift
    type=$1; shift
    [[ $kind = (stopped|all) ]] && args=($args -a)

    lines=(${(f)"$(_call_program commands docker $docker_options ps --format 'table' --no-trunc $args)"})

    # Parse header line to find columns
    local i=1 j=1 k header=${lines[1]}
    declare -A begin end
    while (( j < ${#header} - 1 )); do
        i=$(( j + ${${header[$j,-1]}[(i)[^ ]]} - 1 ))
        j=$(( i + ${${header[$i,-1]}[(i)  ]} - 1 ))
        k=$(( j + ${${header[$j,-1]}[(i)[^ ]]} - 2 ))
        begin[${header[$i,$((j-1))]}]=$i
        end[${header[$i,$((j-1))]}]=$k
    done
    end[${header[$i,$((j-1))]}]=-1 # Last column, should go to the end of the line
    lines=(${lines[2,-1]})

    # Container ID
    if [[ $type = (ids|all) ]]; then
        for line in $lines; do
            s="${${line[${begin[CONTAINER ID]},${end[CONTAINER ID]}]%% ##}[0,12]}"
            s="$s:${(l:15:: :::)${${line[${begin[CREATED]},${end[CREATED]}]/ ago/}%% ##}}"
            s="$s, ${${${line[${begin[IMAGE]},${end[IMAGE]}]}/:/\\:}%% ##}"
            if [[ ${line[${begin[STATUS]},${end[STATUS]}]} = Exit* ]]; then
                stopped=($stopped $s)
            else
                running=($running $s)
            fi
        done
    fi

    # Names: we only display the one without slash. All other names
    # are generated and may clutter the completion. However, with
    # Swarm, all names may be prefixed by the swarm node name.
    if [[ $type = (names|all) ]]; then
        for line in $lines; do
            names=(${(ps:,:)${${line[${begin[NAMES]},${end[NAMES]}]}%% *}})
            # First step: find a common prefix and strip it (swarm node case)
            (( ${#${(u)names%%/*}} == 1 )) && names=${names#${names[1]%%/*}/}
            # Second step: only keep the first name without a /
            s=${${names:#*/*}[1]}
            # If no name, well give up.
            (( $#s != 0 )) || continue
            s="$s:${(l:15:: :::)${${line[${begin[CREATED]},${end[CREATED]}]/ ago/}%% ##}}"
            s="$s, ${${${line[${begin[IMAGE]},${end[IMAGE]}]}/:/\\:}%% ##}"
            if [[ ${line[${begin[STATUS]},${end[STATUS]}]} = Exit* ]]; then
                stopped=($stopped $s)
            else
                running=($running $s)
            fi
        done
    fi

    [[ $kind = (running|all) ]] && _describe -t containers-running "running containers" running "$@" && ret=0
    [[ $kind = (stopped|all) ]] && _describe -t containers-stopped "stopped containers" stopped "$@" && ret=0
    return ret
}

__docker_stoppedcontainers() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_containers stopped all "$@"
}

__docker_runningcontainers() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_containers running all "$@"
}

__docker_containers() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_containers all all "$@"
}

__docker_containers_ids() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_containers all ids "$@"
}

__docker_containers_names() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_containers all names "$@"
}

__docker_plugins() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    emulate -L zsh
    setopt extendedglob
    local -a plugins
    plugins=(${(ps: :)${(M)${(f)${${"$(_call_program commands docker $docker_options info)"##*$'\n'Plugins:}%%$'\n'^ *}}:# $1: *}## $1: })
    _describe -t plugins "$1 plugins" plugins && ret=0
    return ret
}

__docker_images() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    declare -a images
    images=(${${${(f)"$(_call_program commands docker $docker_options images)"}[2,-1]}/(#b)([^ ]##) ##([^ ]##) ##([^ ]##)*/${match[3]}:${(r:15:: :::)match[2]} in ${match[1]}})
    _describe -t docker-images "images" images && ret=0
    __docker_repositories_with_tags && ret=0
    return ret
}

__docker_repositories() {
    [[ $PREFIX = -* ]] && return 1
    declare -a repos
    repos=(${${${(f)"$(_call_program commands docker $docker_options images)"}%% *}[2,-1]})
    repos=(${repos#<none>})
    _describe -t docker-repos "repositories" repos
}

__docker_repositories_with_tags() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    declare -a repos onlyrepos matched
    declare m
    repos=(${${${${(f)"$(_call_program commands docker $docker_options images)"}[2,-1]}/ ##/:::}%% *})
    repos=(${${repos%:::<none>}#<none>})
    # Check if we have a prefix-match for the current prefix.
    onlyrepos=(${repos%::*})
    for m in $onlyrepos; do
        [[ ${PREFIX##${~~m}} != ${PREFIX} ]] && {
            # Yes, complete with tags
            repos=(${${repos/:::/:}/:/\\:})
            _describe -t docker-repos-with-tags "repositories with tags" repos && ret=0
            return ret
        }
    done
    # No, only complete repositories
    onlyrepos=(${${repos%:::*}/:/\\:})
    _describe -t docker-repos "repositories" onlyrepos -qS : && ret=0

    return ret
}

__docker_search() {
    [[ $PREFIX = -* ]] && return 1
    local cache_policy
    zstyle -s ":completion:${curcontext}:" cache-policy cache_policy
    if [[ -z "$cache_policy" ]]; then
        zstyle ":completion:${curcontext}:" cache-policy __docker_caching_policy
    fi

    local searchterm cachename
    searchterm="${words[$CURRENT]%/}"
    cachename=_docker-search-$searchterm

    local expl
    local -a result
    if ( [[ ${(P)+cachename} -eq 0 ]] || _cache_invalid ${cachename#_} ) \
        && ! _retrieve_cache ${cachename#_}; then
        _message "Searching for ${searchterm}..."
        result=(${${${(f)"$(_call_program commands docker $docker_options search $searchterm)"}%% *}[2,-1]})
        _store_cache ${cachename#_} result
    fi
    _wanted dockersearch expl 'available images' compadd -a result
}

__docker_get_log_options() {
    [[ $PREFIX = -* ]] && return 1

    integer ret=1
    local log_driver=${opt_args[--log-driver]:-"all"}
    local -a awslogs_options fluentd_options gelf_options journald_options json_file_options syslog_options splunk_options

    awslogs_options=("awslogs-region" "awslogs-group" "awslogs-stream")
    fluentd_options=("env" "fluentd-address" "fluentd-async-connect" "fluentd-buffer-limit" "fluentd-retry-wait" "fluentd-max-retries" "labels" "tag")
    gcplogs_options=("env" "gcp-log-cmd" "gcp-project" "labels")
    gelf_options=("env" "gelf-address" "gelf-compression-level" "gelf-compression-type" "labels" "tag")
    journald_options=("env" "labels" "tag")
    json_file_options=("env" "labels" "max-file" "max-size")
    syslog_options=("syslog-address" "syslog-format" "syslog-tls-ca-cert" "syslog-tls-cert" "syslog-tls-key" "syslog-tls-skip-verify" "syslog-facility" "tag")
    splunk_options=("env" "labels" "splunk-caname" "splunk-capath" "splunk-index" "splunk-insecureskipverify" "splunk-source" "splunk-sourcetype" "splunk-token" "splunk-url" "tag")

    [[ $log_driver = (awslogs|all) ]] && _describe -t awslogs-options "awslogs options" awslogs_options "$@" && ret=0
    [[ $log_driver = (fluentd|all) ]] && _describe -t fluentd-options "fluentd options" fluentd_options "$@" && ret=0
    [[ $log_driver = (gcplogs|all) ]] && _describe -t gcplogs-options "gcplogs options" gcplogs_options "$@" && ret=0
    [[ $log_driver = (gelf|all) ]] && _describe -t gelf-options "gelf options" gelf_options "$@" && ret=0
    [[ $log_driver = (journald|all) ]] && _describe -t journald-options "journald options" journald_options "$@" && ret=0
    [[ $log_driver = (json-file|all) ]] && _describe -t json-file-options "json-file options" json_file_options "$@" && ret=0
    [[ $log_driver = (syslog|all) ]] && _describe -t syslog-options "syslog options" syslog_options "$@" && ret=0
    [[ $log_driver = (splunk|all) ]] && _describe -t splunk-options "splunk options" splunk_options "$@" && ret=0

    return ret
}

__docker_log_options() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (syslog-format)
                syslog_format_opts=('rfc3164' 'rfc5424' 'rfc5424micro')
                _describe -t syslog-format-opts "Syslog format Options" syslog_format_opts && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        __docker_get_log_options -qS "=" && ret=0
    fi

    return ret
}

__docker_complete_detach_keys() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1

    compset -P "*,"
    keys=(${:-{a-z}})
    ctrl_keys=(${:-ctrl-{{a-z},{@,'[','\\','^',']',_}}})
    _describe -t detach_keys "[a-z]" keys -qS "," && ret=0
    _describe -t detach_keys-ctrl "'ctrl-' + 'a-z @ [ \\\\ ] ^ _'" ctrl_keys -qS "," && ret=0
}

__docker_complete_pid() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    local -a opts vopts

    opts=('host')
    vopts=('container')

    if compset -P '*:'; then
        case "${${words[-1]%:*}#*=}" in
            (container)
                __docker_runningcontainers && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        _describe -t pid-value-opts "PID Options with value" vopts -qS ":" && ret=0
        _describe -t pid-opts "PID Options" opts && ret=0
    fi

    return ret
}

__docker_complete_ps_filters() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (ancestor)
                __docker_images && ret=0
                ;;
            (before|since)
                __docker_containers && ret=0
                ;;
            (id)
                __docker_containers_ids && ret=0
                ;;
            (name)
                __docker_containers_names && ret=0
                ;;
            (network)
                __docker_networks && ret=0
                ;;
            (status)
                status_opts=('created' 'dead' 'exited' 'paused' 'restarting' 'running')
                _describe -t status-filter-opts "Status Filter Options" status_opts && ret=0
                ;;
            (volume)
                __docker_volumes && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        opts=('ancestor' 'before' 'exited' 'id' 'label' 'name' 'network' 'since' 'status' 'volume')
        _describe -t filter-opts "Filter Options" opts -qS "=" && ret=0
    fi

    return ret
}

__docker_complete_search_filters() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    declare -a boolean_opts opts

    boolean_opts=('true' 'false')
    opts=('is-automated' 'is-official' 'stars')

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (is-automated|is-official)
                _describe -t boolean-filter-opts "filter options" boolean_opts && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        _describe -t filter-opts "filter options" opts -qS "=" && ret=0
    fi

    return ret
}

__docker_complete_images_filters() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    declare -a boolean_opts opts

    boolean_opts=('true' 'false')
    opts=('before' 'dangling' 'label' 'since')

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (before|since)
                __docker_images && ret=0
                ;;
            (dangling)
                _describe -t boolean-filter-opts "filter options" boolean_opts && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        _describe -t filter-opts "Filter Options" opts -qS "=" && ret=0
    fi

    return ret
}

__docker_complete_events_filter() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    declare -a opts

    opts=('container' 'daemon' 'event' 'image' 'label' 'network' 'type' 'volume')

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (container)
                __docker_containers && ret=0
                ;;
            (daemon)
                emulate -L zsh
                setopt extendedglob
                local -a daemon_opts
                daemon_opts=(
                    ${(f)${${"$(_call_program commands docker $docker_options info)"##*$'\n'Name: }%%$'\n'^ *}}
                    ${${(f)${${"$(_call_program commands docker $docker_options info)"##*$'\n'ID: }%%$'\n'^ *}}//:/\\:}
                )
                _describe -t daemon-filter-opts "daemon filter options" daemon_opts && ret=0
                ;;
            (event)
                local -a event_opts
                event_opts=('attach' 'commit' 'connect' 'copy' 'create' 'delete' 'destroy' 'detach' 'die' 'disconnect' 'exec_create' 'exec_detach'
                'exec_start' 'export' 'import' 'kill' 'mount' 'oom' 'pause' 'pull' 'push' 'reload' 'rename' 'resize' 'restart' 'start' 'stop' 'tag'
                'top' 'unmount' 'unpause' 'untag' 'update')
                _describe -t event-filter-opts "event filter options" event_opts && ret=0
                ;;
            (image)
                __docker_images && ret=0
                ;;
            (network)
                __docker_networks && ret=0
                ;;
            (type)
                local -a type_opts
                type_opts=('container' 'daemon' 'image' 'network' 'volume')
                _describe -t type-filter-opts "type filter options" type_opts && ret=0
                ;;
            (volume)
                __docker_volumes && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        _describe -t filter-opts "filter options" opts -qS "=" && ret=0
    fi

    return ret
}

__docker_network_complete_ls_filters() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (driver)
                __docker_plugins Network && ret=0
                ;;
            (id)
                __docker_networks_ids && ret=0
                ;;
            (name)
                __docker_networks_names && ret=0
                ;;
            (type)
                type_opts=('builtin' 'custom')
                _describe -t type-filter-opts "Type Filter Options" type_opts && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        opts=('driver' 'id' 'label' 'name' 'type')
        _describe -t filter-opts "Filter Options" opts -qS "=" && ret=0
    fi

    return ret
}

__docker_get_networks() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    local line s
    declare -a lines networks

    type=$1; shift

    lines=(${(f)"$(_call_program commands docker $docker_options network ls)"})

    # Parse header line to find columns
    local i=1 j=1 k header=${lines[1]}
    declare -A begin end
    while (( j < ${#header} - 1 )); do
        i=$(( j + ${${header[$j,-1]}[(i)[^ ]]} - 1 ))
        j=$(( i + ${${header[$i,-1]}[(i)  ]} - 1 ))
        k=$(( j + ${${header[$j,-1]}[(i)[^ ]]} - 2 ))
        begin[${header[$i,$((j-1))]}]=$i
        end[${header[$i,$((j-1))]}]=$k
    done
    end[${header[$i,$((j-1))]}]=-1
    lines=(${lines[2,-1]})

    # Network ID
    if [[ $type = (ids|all) ]]; then
        for line in $lines; do
            s="${line[${begin[NETWORK ID]},${end[NETWORK ID]}]%% ##}"
            s="$s:${(l:7:: :::)${${line[${begin[DRIVER]},${end[DRIVER]}]}%% ##}}"
            networks=($networks $s)
        done
    fi

    # Names
    if [[ $type = (names|all) ]]; then
        for line in $lines; do
            s="${line[${begin[NAME]},${end[NAME]}]%% ##}"
            s="$s:${(l:7:: :::)${${line[${begin[DRIVER]},${end[DRIVER]}]}%% ##}}"
            networks=($networks $s)
        done
    fi

    _describe -t networks-list "networks" networks "$@" && ret=0
    return ret
}

__docker_networks() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_networks all "$@"
}

__docker_networks_ids() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_networks ids "$@"
}

__docker_networks_names() {
    [[ $PREFIX = -* ]] && return 1
    __docker_get_networks names "$@"
}

__docker_network_commands() {
    local -a _docker_network_subcommands
    _docker_network_subcommands=(
        "connect:Connects a container to a network"
        "create:Creates a new network with a name specified by the user"
        "disconnect:Disconnects a container from a network"
        "inspect:Displays detailed information on a network"
        "ls:Lists all the networks created by the user"
        "rm:Deletes one or more networks"
    )
    _describe -t docker-network-commands "docker network command" _docker_network_subcommands
}

__docker_network_subcommand() {
    local -a _command_args opts_help
    local expl help="--help"
    integer ret=1

    opts_help=("(: -)--help[Print usage]")

    case "$words[1]" in
        (connect)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)*--alias=[Add network-scoped alias for the container]:alias: " \
                "($help)--ip=[Container IPv4 address]:IPv4: " \
                "($help)--ip6=[Container IPv6 address]:IPv6: " \
                "($help)*--link=[Add a link to another container]:link:->link" \
                "($help -)1:network:__docker_networks" \
                "($help -)2:containers:__docker_containers" && ret=0

            case $state in
                (link)
                    if compset -P "*:"; then
                        _wanted alias expl "Alias" compadd -E "" && ret=0
                    else
                        __docker_runningcontainers -qS ":" && ret=0
                    fi
                    ;;
            esac
            ;;
        (create)
            _arguments $(__docker_arguments) -A '-*' \
                $opts_help \
                "($help)*--aux-address[Auxiliary IPv4 or IPv6 addresses used by network driver]:key=IP: " \
                "($help -d --driver)"{-d=,--driver=}"[Driver to manage the Network]:driver:(null host bridge overlay)" \
                "($help)*--gateway=[IPv4 or IPv6 Gateway for the master subnet]:IP: " \
                "($help)--internal[Restricts external access to the network]" \
                "($help)*--ip-range=[Allocate container ip from a sub-range]:IP/mask: " \
                "($help)--ipam-driver=[IP Address Management Driver]:driver:(default)" \
                "($help)*--ipam-opt=[Custom IPAM plugin options]:opt=value: " \
                "($help)--ipv6[Enable IPv6 networking]" \
                "($help)*--label=[Set metadata on a network]:label=value: " \
                "($help)*"{-o=,--opt=}"[Driver specific options]:opt=value: " \
                "($help)*--subnet=[Subnet in CIDR format that represents a network segment]:IP/mask: " \
                "($help -)1:Network Name: " && ret=0
            ;;
        (disconnect)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)1:network:__docker_networks" \
                "($help -)2:containers:__docker_containers" && ret=0
            ;;
        (inspect)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -f --format)"{-f=,--format=}"[Format the output using the given go template]:template: " \
                "($help -)*:network:__docker_networks" && ret=0
            ;;
        (ls)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)--no-trunc[Do not truncate the output]" \
                "($help)*"{-f=,--filter=}"[Provide filter values]:filter:->filter-options" \
                "($help -q --quiet)"{-q,--quiet}"[Only display numeric IDs]" && ret=0
            case $state in
                (filter-options)
                    __docker_network_complete_ls_filters && ret=0
                    ;;
            esac
            ;;
        (rm)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)*:network:__docker_networks" && ret=0
            ;;
        (help)
            _arguments $(__docker_arguments) ":subcommand:__docker_network_commands" && ret=0
            ;;
    esac

    return ret
}

__docker_volume_complete_ls_filters() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1

    if compset -P '*='; then
        case "${${words[-1]%=*}#*=}" in
            (dangling)
                dangling_opts=('true' 'false')
                _describe -t dangling-filter-opts "Dangling Filter Options" dangling_opts && ret=0
                ;;
            (driver)
                __docker_plugins Volume && ret=0
                ;;
            (name)
                __docker_volumes && ret=0
                ;;
            *)
                _message 'value' && ret=0
                ;;
        esac
    else
        opts=('dangling' 'driver' 'name')
        _describe -t filter-opts "Filter Options" opts -qS "=" && ret=0
    fi

    return ret
}

__docker_volumes() {
    [[ $PREFIX = -* ]] && return 1
    integer ret=1
    declare -a lines volumes

    lines=(${(f)"$(_call_program commands docker $docker_options volume ls)"})

    # Parse header line to find columns
    local i=1 j=1 k header=${lines[1]}
    declare -A begin end
    while (( j < ${#header} - 1 )); do
        i=$(( j + ${${header[$j,-1]}[(i)[^ ]]} - 1 ))
        j=$(( i + ${${header[$i,-1]}[(i)  ]} - 1 ))
        k=$(( j + ${${header[$j,-1]}[(i)[^ ]]} - 2 ))
        begin[${header[$i,$((j-1))]}]=$i
        end[${header[$i,$((j-1))]}]=$k
    done
    end[${header[$i,$((j-1))]}]=-1
    lines=(${lines[2,-1]})

    # Names
    local line s
    for line in $lines; do
        s="${line[${begin[VOLUME NAME]},${end[VOLUME NAME]}]%% ##}"
        s="$s:${(l:7:: :::)${${line[${begin[DRIVER]},${end[DRIVER]}]}%% ##}}"
        volumes=($volumes $s)
    done

    _describe -t volumes-list "volumes" volumes && ret=0
    return ret
}

__docker_volume_commands() {
    local -a _docker_volume_subcommands
    _docker_volume_subcommands=(
        "create:Create a volume"
        "inspect:Return low-level information on a volume"
        "ls:List volumes"
        "rm:Remove a volume"
    )
    _describe -t docker-volume-commands "docker volume command" _docker_volume_subcommands
}

__docker_volume_subcommand() {
    local -a _command_args opts_help
    local expl help="--help"
    integer ret=1

    opts_help=("(: -)--help[Print usage]")

    case "$words[1]" in
        (create)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -d --driver)"{-d=,--driver=}"[Volume driver name]:Driver name:(local)" \
                "($help)*--label=[Set metadata for a volume]:label=value: " \
                "($help)--name=[Volume name]" \
                "($help)*"{-o=,--opt=}"[Driver specific options]:Driver option: " && ret=0
            ;;
        (inspect)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -f --format)"{-f=,--format=}"[Format the output using the given go template]:template: " \
                "($help -)1:volume:__docker_volumes" && ret=0
            ;;
        (ls)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)*"{-f=,--filter=}"[Provide filter values]:filter:->filter-options" \
                "($help -q --quiet)"{-q,--quiet}"[Only display volume names]" && ret=0
            case $state in
                (filter-options)
                    __docker_volume_complete_ls_filters && ret=0
                    ;;
            esac
            ;;
        (rm)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -):volume:__docker_volumes" && ret=0
            ;;
        (help)
            _arguments $(__docker_arguments) ":subcommand:__docker_volume_commands" && ret=0
            ;;
    esac

    return ret
}

__docker_caching_policy() {
  oldp=( "$1"(Nmh+1) )     # 1 hour
  (( $#oldp ))
}

__docker_commands() {
    local cache_policy

    zstyle -s ":completion:${curcontext}:" cache-policy cache_policy
    if [[ -z "$cache_policy" ]]; then
        zstyle ":completion:${curcontext}:" cache-policy __docker_caching_policy
    fi

    if ( [[ ${+_docker_subcommands} -eq 0 ]] || _cache_invalid docker_subcommands) \
        && ! _retrieve_cache docker_subcommands;
    then
        local -a lines
        lines=(${(f)"$(_call_program commands docker 2>&1)"})
        _docker_subcommands=(${${${lines[$((${lines[(i)Commands:]} + 1)),${lines[(I)    *]}]}## #}/ ##/:})
        _docker_subcommands=($_docker_subcommands 'daemon:Enable daemon mode' 'help:Show help for a command')
        (( $#_docker_subcommands > 2 )) && _store_cache docker_subcommands _docker_subcommands
    fi
    _describe -t docker-commands "docker command" _docker_subcommands
}

__docker_subcommand() {
    local -a _command_args opts_help opts_build_create_run opts_build_create_run_update opts_create_run opts_create_run_update
    local expl help="--help"
    integer ret=1

    opts_help=("(: -)--help[Print usage]")
    opts_build_create_run=(
        "($help)--cgroup-parent=[Parent cgroup for the container]:cgroup: "
        "($help)--isolation=[Container isolation technology]:isolation:(default hyperv process)"
        "($help)--disable-content-trust[Skip image verification]"
        "($help)*--shm-size=[Size of '/dev/shm' (format is '<number><unit>')]:shm size: "
        "($help)*--ulimit=[ulimit options]:ulimit: "
        "($help)--userns=[Container user namespace]:user namespace:(host)"
    )
    opts_build_create_run_update=(
        "($help)--cpu-shares=[CPU shares (relative weight)]:CPU shares:(0 10 100 200 500 800 1000)"
        "($help)--cpu-period=[Limit the CPU CFS (Completely Fair Scheduler) period]:CPU period: "
        "($help)--cpu-quota=[Limit the CPU CFS (Completely Fair Scheduler) quota]:CPU quota: "
        "($help)--cpuset-cpus=[CPUs in which to allow execution]:CPUs: "
        "($help)--cpuset-mems=[MEMs in which to allow execution]:MEMs: "
        "($help -m --memory)"{-m=,--memory=}"[Memory limit]:Memory limit: "
        "($help)--memory-swap=[Total memory limit with swap]:Memory limit: "
    )
    opts_create_run=(
        "($help -a --attach)"{-a=,--attach=}"[Attach to stdin, stdout or stderr]:device:(STDIN STDOUT STDERR)"
        "($help)*--add-host=[Add a custom host-to-IP mapping]:host\:ip mapping: "
        "($help)*--blkio-weight-device=[Block IO (relative device weight)]:device:Block IO weight: "
        "($help)*--cap-add=[Add Linux capabilities]:capability: "
        "($help)*--cap-drop=[Drop Linux capabilities]:capability: "
        "($help)--cidfile=[Write the container ID to the file]:CID file:_files"
        "($help)*--device=[Add a host device to the container]:device:_files"
        "($help)*--device-read-bps=[Limit the read rate (bytes per second) from a device]:device:IO rate: "
        "($help)*--device-read-iops=[Limit the read rate (IO per second) from a device]:device:IO rate: "
        "($help)*--device-write-bps=[Limit the write rate (bytes per second) to a device]:device:IO rate: "
        "($help)*--device-write-iops=[Limit the write rate (IO per second) to a device]:device:IO rate: "
        "($help)*--dns=[Custom DNS servers]:DNS server: "
        "($help)*--dns-opt=[Custom DNS options]:DNS option: "
        "($help)*--dns-search=[Custom DNS search domains]:DNS domains: "
        "($help)*"{-e=,--env=}"[Environment variables]:environment variable: "
        "($help)--entrypoint=[Overwrite the default entrypoint of the image]:entry point: "
        "($help)*--env-file=[Read environment variables from a file]:environment file:_files"
        "($help)*--expose=[Expose a port from the container without publishing it]: "
        "($help)*--group-add=[Add additional groups to run as]:group:_groups"
        "($help -h --hostname)"{-h=,--hostname=}"[Container host name]:hostname:_hosts"
        "($help -i --interactive)"{-i,--interactive}"[Keep stdin open even if not attached]"
        "($help)--ip=[Container IPv4 address]:IPv4: "
        "($help)--ip6=[Container IPv6 address]:IPv6: "
        "($help)--ipc=[IPC namespace to use]:IPC namespace: "
        "($help)*--link=[Add link to another container]:link:->link"
        "($help)*"{-l=,--label=}"[Container metadata]:label: "
        "($help)--log-driver=[Default driver for container logs]:Logging driver:(awslogs etwlogs fluentd gcplogs gelf journald json-file none splunk syslog)"
        "($help)*--log-opt=[Log driver specific options]:log driver options:__docker_log_options"
        "($help)--mac-address=[Container MAC address]:MAC address: "
        "($help)--name=[Container name]:name: "
        "($help)--net=[Connect a container to a network]:network mode:(bridge none container host)"
        "($help)*--net-alias=[Add network-scoped alias for the container]:alias: "
        "($help)--oom-kill-disable[Disable OOM Killer]"
        "($help)--oom-score-adj[Tune the host's OOM preferences for containers (accepts -1000 to 1000)]"
        "($help)--pids-limit[Tune container pids limit (set -1 for unlimited)]"
        "($help -P --publish-all)"{-P,--publish-all}"[Publish all exposed ports]"
        "($help)*"{-p=,--publish=}"[Expose a container's port to the host]:port:_ports"
        "($help)--pid=[PID namespace to use]:PID namespace:__docker_complete_pid"
        "($help)--privileged[Give extended privileges to this container]"
        "($help)--read-only[Mount the container's root filesystem as read only]"
        "($help)*--security-opt=[Security options]:security option: "
        "($help)*--sysctl=-[sysctl options]:sysctl: "
        "($help -t --tty)"{-t,--tty}"[Allocate a pseudo-tty]"
        "($help -u --user)"{-u=,--user=}"[Username or UID]:user:_users"
        "($help)--tmpfs[mount tmpfs]"
        "($help)*-v[Bind mount a volume]:volume: "
        "($help)--volume-driver=[Optional volume driver for the container]:volume driver:(local)"
        "($help)*--volumes-from=[Mount volumes from the specified container]:volume: "
        "($help -w --workdir)"{-w=,--workdir=}"[Working directory inside the container]:directory:_directories"
    )
    opts_create_run_update=(
        "($help)--blkio-weight=[Block IO (relative weight), between 10 and 1000]:Block IO weight:(10 100 500 1000)"
        "($help)--kernel-memory=[Kernel memory limit in bytes]:Memory limit: "
        "($help)--memory-reservation=[Memory soft limit]:Memory limit: "
        "($help)--restart=[Restart policy]:restart policy:(no on-failure always unless-stopped)"
    )
    opts_attach_exec_run_start=(
        "($help)--detach-keys=[Escape key sequence used to detach a container]:sequence:__docker_complete_detach_keys"
    )

    case "$words[1]" in
        (attach)
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_attach_exec_run_start \
                "($help)--no-stdin[Do not attach stdin]" \
                "($help)--sig-proxy[Proxy all received signals to the process (non-TTY mode only)]" \
                "($help -):containers:__docker_runningcontainers" && ret=0
            ;;
        (build)
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_build_create_run \
                $opts_build_create_run_update \
                "($help)*--build-arg[Build-time variables]:<varname>=<value>: " \
                "($help -f --file)"{-f=,--file=}"[Name of the Dockerfile]:Dockerfile:_files" \
                "($help)--force-rm[Always remove intermediate containers]" \
                "($help)*--label=[Set metadata for an image]:label=value: " \
                "($help)--no-cache[Do not use cache when building the image]" \
                "($help)--pull[Attempt to pull a newer version of the image]" \
                "($help -q --quiet)"{-q,--quiet}"[Suppress verbose build output]" \
                "($help)--rm[Remove intermediate containers after a successful build]" \
                "($help -t --tag)*"{-t=,--tag=}"[Repository, name and tag for the image]: :__docker_repositories_with_tags" \
                "($help -):path or URL:_directories" && ret=0
            ;;
        (commit)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -a --author)"{-a=,--author=}"[Author]:author: " \
                "($help)*"{-c=,--change=}"[Apply Dockerfile instruction to the created image]:Dockerfile:_files" \
                "($help -m --message)"{-m=,--message=}"[Commit message]:message: " \
                "($help -p --pause)"{-p,--pause}"[Pause container during commit]" \
                "($help -):container:__docker_containers" \
                "($help -): :__docker_repositories_with_tags" && ret=0
            ;;
        (cp)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -L --follow-link)"{-L,--follow-link}"[Always follow symbol link]" \
                "($help -)1:container:->container" \
                "($help -)2:hostpath:_files" && ret=0
            case $state in
                (container)
                    if compset -P "*:"; then
                        _files && ret=0
                    else
                        __docker_containers -qS ":" && ret=0
                    fi
                    ;;
            esac
            ;;
        (create)
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_build_create_run \
                $opts_build_create_run_update \
                $opts_create_run \
                $opts_create_run_update \
                "($help -): :__docker_images" \
                "($help -):command: _command_names -e" \
                "($help -)*::arguments: _normal" && ret=0

            case $state in
                (link)
                    if compset -P "*:"; then
                        _wanted alias expl "Alias" compadd -E "" && ret=0
                    else
                        __docker_runningcontainers -qS ":" && ret=0
                    fi
                    ;;
            esac

            ;;
        (daemon)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)--api-cors-header=[CORS headers in the remote API]:CORS headers: " \
                "($help)*--authorization-plugin=[Authorization plugins to load]" \
                "($help -b --bridge)"{-b=,--bridge=}"[Attach containers to a network bridge]:bridge:_net_interfaces" \
                "($help)--bip=[Network bridge IP]:IP address: " \
                "($help)--cgroup-parent=[Parent cgroup for all containers]:cgroup: " \
                "($help)--config-file=[Path to daemon configuration file]:Config File:_files" \
                "($help)--containerd=[Path to containerd socket]:socket:_files -g \"*.sock\"" \
                "($help -D --debug)"{-D,--debug}"[Enable debug mode]" \
                "($help)--default-gateway[Container default gateway IPv4 address]:IPv4 address: " \
                "($help)--default-gateway-v6[Container default gateway IPv6 address]:IPv6 address: " \
                "($help)--cluster-store=[URL of the distributed storage backend]:Cluster Store:->cluster-store" \
                "($help)--cluster-advertise=[Address of the daemon instance to advertise]:Instance to advertise (host\:port): " \
                "($help)*--cluster-store-opt=[Cluster options]:Cluster options:->cluster-store-options" \
                "($help)*--dns=[DNS server to use]:DNS: " \
                "($help)*--dns-search=[DNS search domains to use]:DNS search: " \
                "($help)*--dns-opt=[DNS options to use]:DNS option: " \
                "($help)*--default-ulimit=[Default ulimit settings for containers]:ulimit: " \
                "($help)--disable-legacy-registry[Do not contact legacy registries]" \
                "($help)*--exec-opt=[Runtime execution options]:runtime execution options: " \
                "($help)--exec-root=[Root directory for execution state files]:path:_directories" \
                "($help)--fixed-cidr=[IPv4 subnet for fixed IPs]:IPv4 subnet: " \
                "($help)--fixed-cidr-v6=[IPv6 subnet for fixed IPs]:IPv6 subnet: " \
                "($help -G --group)"{-G=,--group=}"[Group for the unix socket]:group:_groups" \
                "($help -g --graph)"{-g=,--graph=}"[Root of the Docker runtime]:path:_directories" \
                "($help -H --host)"{-H=,--host=}"[tcp://host:port to bind/connect to]:host: " \
                "($help)--icc[Enable inter-container communication]" \
                "($help)*--insecure-registry=[Enable insecure registry communication]:registry: " \
                "($help)--ip=[Default IP when binding container ports]" \
                "($help)--ip-forward[Enable net.ipv4.ip_forward]" \
                "($help)--ip-masq[Enable IP masquerading]" \
                "($help)--iptables[Enable addition of iptables rules]" \
                "($help)--ipv6[Enable IPv6 networking]" \
                "($help -l --log-level)"{-l=,--log-level=}"[Logging level]:level:(debug info warn error fatal)" \
                "($help)*--label=[Key=value labels]:label: " \
                "($help)--log-driver=[Default driver for container logs]:Logging driver:(awslogs etwlogs fluentd gcplogs gelf journald json-file none splunk syslog)" \
                "($help)*--log-opt=[Log driver specific options]:log driver options:__docker_log_options" \
                "($help)--max-concurrent-downloads[Set the max concurrent downloads for each pull]" \
                "($help)--max-concurrent-uploads[Set the max concurrent uploads for each push]" \
                "($help)--mtu=[Network MTU]:mtu:(0 576 1420 1500 9000)" \
                "($help -p --pidfile)"{-p=,--pidfile=}"[Path to use for daemon PID file]:PID file:_files" \
                "($help)--raw-logs[Full timestamps without ANSI coloring]" \
                "($help)*--registry-mirror=[Preferred Docker registry mirror]:registry mirror: " \
                "($help -s --storage-driver)"{-s=,--storage-driver=}"[Storage driver to use]:driver:(aufs devicemapper btrfs zfs overlay)" \
                "($help)--selinux-enabled[Enable selinux support]" \
                "($help)*--storage-opt=[Storage driver options]:storage driver options: " \
                "($help)--tls[Use TLS]" \
                "($help)--tlscacert=[Trust certs signed only by this CA]:PEM file:_files -g \"*.(pem|crt)\"" \
                "($help)--tlscert=[Path to TLS certificate file]:PEM file:_files -g \"*.(pem|crt)\"" \
                "($help)--tlskey=[Path to TLS key file]:Key file:_files -g \"*.(pem|key)\"" \
                "($help)--tlsverify[Use TLS and verify the remote]" \
                "($help)--userns-remap=[User/Group setting for user namespaces]:user\:group:->users-groups" \
                "($help)--userland-proxy[Use userland proxy for loopback traffic]" && ret=0

            case $state in
                (cluster-store)
                    if compset -P '*://'; then
                        _message 'host:port' && ret=0
                    else
                        store=('consul' 'etcd' 'zk')
                        _describe -t cluster-store "Cluster Store" store -qS "://" && ret=0
                    fi
                    ;;
                (cluster-store-options)
                    if compset -P '*='; then
                        _files && ret=0
                    else
                        opts=('discovery.heartbeat' 'discovery.ttl' 'kv.cacertfile' 'kv.certfile' 'kv.keyfile' 'kv.path')
                        _describe -t cluster-store-opts "Cluster Store Options" opts -qS "=" && ret=0
                    fi
                    ;;
                (users-groups)
                    if compset -P '*:'; then
                        _groups && ret=0
                    else
                        _describe -t userns-default "default Docker user management" '(default)' && ret=0
                        _users && ret=0
                    fi
                    ;;
            esac
            ;;
        (diff)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)*:containers:__docker_containers" && ret=0
            ;;
        (events)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)*"{-f=,--filter=}"[Filter values]:filter:__docker_complete_events_filter" \
                "($help)--since=[Events created since this timestamp]:timestamp: " \
                "($help)--until=[Events created until this timestamp]:timestamp: " && ret=0
            ;;
        (exec)
            local state
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_attach_exec_run_start \
                "($help -d --detach)"{-d,--detach}"[Detached mode: leave the container running in the background]" \
                "($help -i --interactive)"{-i,--interactive}"[Keep stdin open even if not attached]" \
                "($help)--privileged[Give extended Linux capabilities to the command]" \
                "($help -t --tty)"{-t,--tty}"[Allocate a pseudo-tty]" \
                "($help -u --user)"{-u=,--user=}"[Username or UID]:user:_users" \
                "($help -):containers:__docker_runningcontainers" \
                "($help -)*::command:->anycommand" && ret=0

            case $state in
                (anycommand)
                    shift 1 words
                    (( CURRENT-- ))
                    _normal && ret=0
                    ;;
            esac
            ;;
        (export)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -o --output)"{-o=,--output=}"[Write to a file, instead of stdout]:output file:_files" \
                "($help -)*:containers:__docker_containers" && ret=0
            ;;
        (history)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -H --human)"{-H,--human}"[Print sizes and dates in human readable format]" \
                "($help)--no-trunc[Do not truncate output]" \
                "($help -q --quiet)"{-q,--quiet}"[Only show numeric IDs]" \
                "($help -)*: :__docker_images" && ret=0
            ;;
        (images)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -a --all)"{-a,--all}"[Show all images]" \
                "($help)--digests[Show digests]" \
                "($help)*"{-f=,--filter=}"[Filter values]:filter:->filter-options" \
                "($help)--format[Pretty-print containers using a Go template]:format: " \
                "($help)--no-trunc[Do not truncate output]" \
                "($help -q --quiet)"{-q,--quiet}"[Only show numeric IDs]" \
                "($help -): :__docker_repositories" && ret=0

            case $state in
                (filter-options)
                    __docker_complete_images_filters && ret=0
                    ;;
            esac
            ;;
        (import)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)*"{-c=,--change=}"[Apply Dockerfile instruction to the created image]:Dockerfile:_files" \
                "($help -m --message)"{-m=,--message=}"[Commit message for imported image]:message: " \
                "($help -):URL:(- http:// file://)" \
                "($help -): :__docker_repositories_with_tags" && ret=0
            ;;
        (info|version)
            _arguments $(__docker_arguments) \
                $opts_help && ret=0
            ;;
        (inspect)
            local state
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -f --format)"{-f=,--format=}"[Format the output using the given go template]:template: " \
                "($help -s --size)"{-s,--size}"[Display total file sizes if the type is container]" \
                "($help)--type=[Return JSON for specified type]:type:(image container)" \
                "($help -)*: :->values" && ret=0

            case $state in
                (values)
                    if [[ ${words[(r)--type=container]} == --type=container ]]; then
                        __docker_containers && ret=0
                    elif [[ ${words[(r)--type=image]} == --type=image ]]; then
                        __docker_images && ret=0
                    else
                        __docker_images && __docker_containers && ret=0
                    fi
                    ;;
            esac
            ;;
        (kill)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -s --signal)"{-s=,--signal=}"[Signal to send]:signal:_signals" \
                "($help -)*:containers:__docker_runningcontainers" && ret=0
            ;;
        (load)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -i --input)"{-i=,--input=}"[Read from tar archive file]:archive file:_files -g \"*.((tar|TAR)(.gz|.GZ|.Z|.bz2|.lzma|.xz|)|(tbz|tgz|txz))(-.)\"" \
                "($help -q --quiet)"{-q,--quiet}"[Suppress the load output]" && ret=0
            ;;
        (login)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -p --password)"{-p=,--password=}"[Password]:password: " \
                "($help -u --user)"{-u=,--user=}"[Username]:username: " \
                "($help -)1:server: " && ret=0
            ;;
        (logout)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)1:server: " && ret=0
            ;;
        (logs)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)--details[Show extra details provided to logs]" \
                "($help -f --follow)"{-f,--follow}"[Follow log output]" \
                "($help -s --since)"{-s=,--since=}"[Show logs since this timestamp]:timestamp: " \
                "($help -t --timestamps)"{-t,--timestamps}"[Show timestamps]" \
                "($help)--tail=[Output the last K lines]:lines:(1 10 20 50 all)" \
                "($help -)*:containers:__docker_containers" && ret=0
            ;;
        (network)
            local curcontext="$curcontext" state
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -): :->command" \
                "($help -)*:: :->option-or-argument" && ret=0

            case $state in
                (command)
                    __docker_network_commands && ret=0
                    ;;
                (option-or-argument)
                    curcontext=${curcontext%:*:*}:docker-${words[-1]}:
                    __docker_network_subcommand && ret=0
                    ;;
            esac
            ;;
        (pause|unpause)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)*:containers:__docker_runningcontainers" && ret=0
            ;;
        (port)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)1:containers:__docker_runningcontainers" \
                "($help -)2:port:_ports" && ret=0
            ;;
        (ps)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -a --all)"{-a,--all}"[Show all containers]" \
                "($help)--before=[Show only container created before...]:containers:__docker_containers" \
                "($help)*"{-f=,--filter=}"[Filter values]:filter:__docker_complete_ps_filters" \
                "($help)--format[Pretty-print containers using a Go template]:format: " \
                "($help -l --latest)"{-l,--latest}"[Show only the latest created container]" \
                "($help)-n[Show n last created containers, include non-running one]:n:(1 5 10 25 50)" \
                "($help)--no-trunc[Do not truncate output]" \
                "($help -q --quiet)"{-q,--quiet}"[Only show numeric IDs]" \
                "($help -s --size)"{-s,--size}"[Display total file sizes]" \
                "($help)--since=[Show only containers created since...]:containers:__docker_containers" && ret=0
            ;;
        (pull)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -a --all-tags)"{-a,--all-tags}"[Download all tagged images]" \
                "($help)--disable-content-trust[Skip image verification]" \
                "($help -):name:__docker_search" && ret=0
            ;;
        (push)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)--disable-content-trust[Skip image signing]" \
                "($help -): :__docker_images" && ret=0
            ;;
        (rename)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -):old name:__docker_containers" \
                "($help -):new name: " && ret=0
            ;;
        (restart|stop)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -t --time)"{-t=,--time=}"[Number of seconds to try to stop for before killing the container]:seconds to before killing:(1 5 10 30 60)" \
                "($help -)*:containers:__docker_runningcontainers" && ret=0
            ;;
        (rm)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -f --force)"{-f,--force}"[Force removal]" \
                "($help -l --link)"{-l,--link}"[Remove the specified link and not the underlying container]" \
                "($help -v --volumes)"{-v,--volumes}"[Remove the volumes associated to the container]" \
                "($help -)*:containers:->values" && ret=0
            case $state in
                (values)
                    if [[ ${words[(r)-f]} == -f || ${words[(r)--force]} == --force ]]; then
                        __docker_containers && ret=0
                    else
                        __docker_stoppedcontainers && ret=0
                    fi
                    ;;
            esac
            ;;
        (rmi)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -f --force)"{-f,--force}"[Force removal]" \
                "($help)--no-prune[Do not delete untagged parents]" \
                "($help -)*: :__docker_images" && ret=0
            ;;
        (run)
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_build_create_run \
                $opts_build_create_run_update \
                $opts_create_run \
                $opts_create_run_update \
                $opts_attach_exec_run_start \
                "($help -d --detach)"{-d,--detach}"[Detached mode: leave the container running in the background]" \
                "($help)--health-cmd=[Command to run to check health]:command: " \
                "($help)--health-interval=[Time between running the check]:time: " \
                "($help)--health-retries=[Consecutive failures needed to report unhealthy]:retries:(1 2 3 4 5)" \
                "($help)--health-timeout=[Maximum time to allow one check to run]:time: " \
                "($help)--no-healthcheck[Disable any container-specified HEALTHCHECK]" \
                "($help)--rm[Remove intermediate containers when it exits]" \
                "($help)--sig-proxy[Proxy all received signals to the process (non-TTY mode only)]" \
                "($help)--stop-signal=[Signal to kill a container]:signal:_signals" \
                "($help -): :__docker_images" \
                "($help -):command: _command_names -e" \
                "($help -)*::arguments: _normal" && ret=0

            case $state in
                (link)
                    if compset -P "*:"; then
                        _wanted alias expl "Alias" compadd -E "" && ret=0
                    else
                        __docker_runningcontainers -qS ":" && ret=0
                    fi
                    ;;
            esac

            ;;
        (save)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -o --output)"{-o=,--output=}"[Write to file]:file:_files" \
                "($help -)*: :__docker_images" && ret=0
            ;;
        (search)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help)*"{-f=,--filter=}"[Filter values]:filter:->filter-options" \
                "($help)--limit=[Maximum returned search results]:limit:(1 5 10 25 50)" \
                "($help)--no-trunc[Do not truncate output]" \
                "($help -):term: " && ret=0

            case $state in
                (filter-options)
                    __docker_complete_search_filters && ret=0
                    ;;
            esac
            ;;
        (start)
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_attach_exec_run_start \
                "($help -a --attach)"{-a,--attach}"[Attach container's stdout/stderr and forward all signals]" \
                "($help -i --interactive)"{-i,--interactive}"[Attach container's stding]" \
                "($help -)*:containers:__docker_stoppedcontainers" && ret=0
            ;;
        (stats)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -a --all)"{-a,--all}"[Show all containers (default shows just running)]" \
                "($help)--no-stream[Disable streaming stats and only pull the first result]" \
                "($help -)*:containers:__docker_runningcontainers" && ret=0
            ;;
        (tag)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -):source:__docker_images"\
                "($help -):destination:__docker_repositories_with_tags" && ret=0
            ;;
        (top)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)1:containers:__docker_runningcontainers" \
                "($help -)*:: :->ps-arguments" && ret=0
            case $state in
                (ps-arguments)
                    _ps && ret=0
                    ;;
            esac

            ;;
        (update)
            _arguments $(__docker_arguments) \
                $opts_help \
                $opts_create_run_update \
                $opts_build_create_run_update \
                "($help -)*: :->values" && ret=0

            case $state in
                (values)
                    if [[ ${words[(r)--kernel-memory*]} = (--kernel-memory*) ]]; then
                        __docker_stoppedcontainers && ret=0
                    else
                        __docker_containers && ret=0
                    fi
                    ;;
            esac
            ;;
        (volume)
            local curcontext="$curcontext" state
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -): :->command" \
                "($help -)*:: :->option-or-argument" && ret=0

            case $state in
                (command)
                    __docker_volume_commands && ret=0
                    ;;
                (option-or-argument)
                    curcontext=${curcontext%:*:*}:docker-${words[-1]}:
                    __docker_volume_subcommand && ret=0
                    ;;
            esac
            ;;
        (wait)
            _arguments $(__docker_arguments) \
                $opts_help \
                "($help -)*:containers:__docker_runningcontainers" && ret=0
            ;;
        (help)
            _arguments $(__docker_arguments) ":subcommand:__docker_commands" && ret=0
            ;;
    esac

    return ret
}

_docker() {
    # Support for subservices, which allows for `compdef _docker docker-shell=_docker_containers`.
    # Based on /usr/share/zsh/functions/Completion/Unix/_git without support for `ret`.
    if [[ $service != docker ]]; then
        _call_function - _$service
        return
    fi

    local curcontext="$curcontext" state line help="-h --help"
    integer ret=1
    typeset -A opt_args

    _arguments $(__docker_arguments) -C \
        "(: -)"{-h,--help}"[Print usage]" \
        "($help)--config[Location of client config files]:path:_directories" \
        "($help -D --debug)"{-D,--debug}"[Enable debug mode]" \
        "($help -H --host)"{-H=,--host=}"[tcp://host:port to bind/connect to]:host: " \
        "($help -l --log-level)"{-l=,--log-level=}"[Logging level]:level:(debug info warn error fatal)" \
        "($help)--tls[Use TLS]" \
        "($help)--tlscacert=[Trust certs signed only by this CA]:PEM file:_files -g "*.(pem|crt)"" \
        "($help)--tlscert=[Path to TLS certificate file]:PEM file:_files -g "*.(pem|crt)"" \
        "($help)--tlskey=[Path to TLS key file]:Key file:_files -g "*.(pem|key)"" \
        "($help)--tlsverify[Use TLS and verify the remote]" \
        "($help)--userland-proxy[Use userland proxy for loopback traffic]" \
        "($help -v --version)"{-v,--version}"[Print version information and quit]" \
        "($help -): :->command" \
        "($help -)*:: :->option-or-argument" && ret=0

    local host=${opt_args[-H]}${opt_args[--host]}
    local config=${opt_args[--config]}
    local docker_options="${host:+--host $host} ${config:+--config $config}"

    case $state in
        (command)
            __docker_commands && ret=0
            ;;
        (option-or-argument)
            curcontext=${curcontext%:*:*}:docker-$words[1]:
            __docker_subcommand && ret=0
            ;;
    esac

    return ret
}

compdef _docker docker

# Local Variables:
# mode: Shell-Script
# sh-indentation: 4
# indent-tabs-mode: nil
# sh-basic-offset: 4
# End:
# vim: ft=zsh sw=4 ts=4 et
