# opendaylight.sh - DevStack extras script

ODL_FOUND=$(echo $Q_ML2_PLUGIN_MECHANISM_DRIVERS | grep -q opendaylight ; echo $?)
if [ "$ODL_FOUND" == "0" ] ; then
    if [[ "$1" == "source" ]]; then
        # Initial source
        source $TOP_DIR/lib/neutron
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # OpenDaylight configuration comes after all services are up
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Initializing OpenDaylight"
        read ovstbl <<< $(sudo ovs-vsctl get Open_vSwitch . _uuid)
        ODL_HOST=$(grep url /$Q_PLUGIN_CONF_FILE | sed -e s'/.*\/\///'g -e 's/\:.*//'g)
        sudo ovs-vsctl set-manager tcp:$ODL_HOST:6640
        sudo ovs-vsctl set Open_vSwitch $ovstbl other_config={"local_ip"="$HOST_IP"}
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "unstack" ]]; then
        sudo ovs-vsctl del-manager
        BRIDGES=$(sudo ovs-vsctl list-br)
        for bridge in $BRIDGES ; do
            sudo ovs-vsctl del-controller $bridge
        done
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi

