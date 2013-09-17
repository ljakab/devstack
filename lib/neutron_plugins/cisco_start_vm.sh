#!/usr/bin/env bash

:<<EOF
   1. Create a network profile
$neutron cisco-network-profile-create PROFILE_NAME vlan --segment_range 400-499 --physical_network PHYSICAL_NETWORK_NAME
       * segment type can be of type vlan and vxlan.
   2. Create a network
$neutron net-create NETWORK_NAME --n1kv:profile_id PROFILE_ID
       * The above PROFILE_ID is that of the network profile created in step 1.
   3. Create a subnet
$neutron subnet-create NETWORK_NAME 10.0.0.1/24 --name SUBNET_NAME
       * NETWORK_NAME corresponds to the network created in step 2.
   4. Create a port
$neutron port-create NETWORK_NAME --n1kv:profile_id PROFILE_ID
       * The above PROFILE_ID is that of the policy profile received from VSM. You can get the UUID from the output of 'neutron policy-profile-list'.
       * Remember the ip-address assigned to this port. Use this ip address to configure your VM in step 6.
   5. Create a VM
$nova boot --image IMAGE_ID --flavor 1 --nic port-id=PORT_ID VM_NAME
       * IMAGE_ID can be found out by executing "nova image-list" command. Just pick the first image id.
       * NETWORK_ID is the network uuid from step 2
       * PORT_ID is the port uuid from step 5
   6. VNC into your guest instance. Configure ip-address (from step 4) for this instance.
EOF

set -x

NETWORK_PROFILE_NAME=${NETWORK_PROFILE_NAME:-np_test}
VLAN_RANGE=${VLAN_RANGE:-400-499}
NETWORK_NAME=${NETWORK_NAME:-test_net}
SUBNET_NAME=${SUBNET_NAME:-test_subnet}
SUBNET_IP=${SUBNET_IP:-168.168.168.0/24}
IMAGE_NAME=${IMAGE_NAME:-cirros-0.3.1-x86_64-uec}
POLICY_PROFILE_NAME=${POLICY_PROFILE_NAME:-test-profile}

np_id=''
net_id=''
subnet_id=''
policy_id=''
image_id=''
port_id=''
function get_np_id() {
    np_id=$(neutron cisco-network-profile-list | awk -v np_name=$NETWORK_PROFILE_NAME '(NR > 3) {if ($4 == np_name) {print $2;}}')
}

function get_net_id() {
    net_id=$(neutron net-list | awk -v net_name=$NETWORK_NAME '(NR > 3) {if ($4 == net_name) {print $2;}}')
}

function get_subnet_id() {
    subnet_id=$(neutron subnet-list | awk -v subnet_name=$SUBNET_NAME '(NR > 3) {if ($4 == subnet_name) {print $2;}}')
}

function get_policy_id() {
    policy_id=$(neutron cisco-policy-profile-list | awk -v policy_name=$POLICY_PROFILE_NAME '(NR > 3) {if ($4 == policy_name) {print $2;}}')
    if [[ $policy_id == '' ]]; then
        policy_id=$(neutron cisco-policy-profile-list | awk '(NR == 4) {print $2;}')
    fi
}

function get_image_id() {
    image_id=$(nova image-list | awk -v image_name=$IMAGE_NAME '(NR > 3) {if ($4 == image_name) {print $2;}}')
}

get_image_id
if [[ $image_id == '' ]]; then
    echo "Image $IMAGE_NAME not found!!"
    exit 1
fi

get_np_id
if [[ $np_id == '' ]]; then
    echo "neutron cisco-network-profile-create $NETWORK_PROFILE_NAME vlan --segment_range $VLAN_RANGE --physical_network phyname"
    neutron cisco-network-profile-create $NETWORK_PROFILE_NAME vlan --segment_range $VLAN_RANGE --physical_network phyname
    get_np_id
    if [[ $np_id == '' ]]; then
        exit 1
    fi
fi

get_net_id
if [[ $net_id == '' ]]; then
    echo "neutron net-create $NETWORK_NAME --n1kv:profile_id $np_id"
    neutron net-create $NETWORK_NAME --n1kv:profile_id $np_id
    get_net_id
    if [[ $net_id == '' ]]; then
        exit 1
    fi
fi

get_subnet_id
if [[ $subnet_id == '' ]]; then
    echo "neutron subnet-create $NETWORK_NAME $SUBNET_IP --name $SUBNET_NAME"
    neutron subnet-create $NETWORK_NAME $SUBNET_IP --name $SUBNET_NAME
    get_subnet_id
    if [[ $subnet_id == '' ]]; then
        exit 1
    fi
fi

get_policy_id
if [[ $policy_id != '' ]]; then
    echo "neutron port-create $NETWORK_NAME --n1kv:profile_id $policy_id"
    port_id=$(neutron port-create $NETWORK_NAME --n1kv:profile_id $policy_id | awk '$2=="id" {print $4;}')
fi

if [[ $port_id != '' ]]; then
    rno=$RANDOM
    echo "nova boot --image $image_id --flavor 1 --nic port-id=$port_id VM_$rno"
    nova boot --image $image_id --flavor 1 --nic port-id=$port_id VM_$rno
fi
