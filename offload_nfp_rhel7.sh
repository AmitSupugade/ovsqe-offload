########### BEFORE REBOOT ######################
echo "sslverify=false" >> /etc/yum.conf
yum -y install wget
wget -O /etc/yum.repos.d/beaker-client.repo http://download.lab.bos.redhat.com/beakerrepos/beaker-client-RedHatEnterpriseLinux.repo
yum -y install rhts-test-env beakerlib rhts-devel rhts-python beakerlib-redhat beaker-client beaker-redhat

(
    echo [beaker-tasks]
    echo name=beaker-tasks
    echo baseurl=http://beaker.engineering.redhat.com/rpms
    echo enabled=1
    echo gpgcheck=0
    echo skip_if_unavailable=1
) > /etc/yum.repos.d/beaker-tasks.repo

git_install() {
    if rpm -q git 2>/dev/null; then
        echo "Git is already installed; doing a git pull"; cd /mnt/tests/kernel; git pull
        return 0
    else
            yum -y install git
            mkdir /mnt/tests
        cd /mnt/tests && git clone git://pkgs.devel.redhat.com/tests/kernel
    fi
}
git_install

cd;  . /mnt/tests/kernel/networking/common/include.sh

cat <<'EOT' >> /etc/yum.repos.d/python34.repo
[centos-sclo-rh]
name=CentOS-7 - SCLo rh
baseurl=http://mirror.centos.org/centos/7/sclo/$basearch/rh/
gpgcheck=0
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo
EOT

yum install -y rh-python34 rh-python34-python-tkinter
yum -y install scl-utils
scl enable rh-python34 bash
python --version

nic="enp132s0np0"

. /mnt/tests/kernel/networking/common/include.sh
. /mnt/tests/kernel/networking/common/lib/lib_nc_sync.sh 
. /mnt/tests/kernel/networking/common/lib/lib_netperf_all.sh

. /mnt/tests/kernel/networking/openvswitch/offload/offload_topo_common.sh


vnic1=""
vnic2=""
vfr0=""
vfr1=""
vnic1_bus_info=""
vnic2_bus_info=""

vnic1_mac="e4:11:22:33:44:60"
vnic2_mac="e4:11:22:33:44:61"

NAY=yes
NIC_NUM=1
TOPO=nic
NIC_DRIVER="nfp"

ovs="openvswitch-2.9.0-94.el7fdp.x86_64.rpm"
selinux="http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/8.el7fdp/noarch/openvswitch-selinux-extra-policy-1.0-8.el7fdp.noarch.rpm"
dpdk="1811-2"

ovs_rpm=$ovs
sel_link=$selinux
dpdk_version=$dpdk


THOUGHPUT_64=9444460
THROUGHPUT_1500=1782998

frames="64"
flows="1 10"
policies="skip_sw skip_hw"

result_file="nfp_1PF1VF.log"
tc_result_file="tc_nfp_1PF1VF.log"

results=()
tc_results=()

topology="1pf1vf"
upload=${upload:- 'no'}
upload=$(echo "$upload" | awk '{print tolower($0)}')

packages_install
cpu_partitioning $nic
qemu_install
reboot

############ AFTER REBOOT ###############


scl enable rh-python34 bash
python --version

nic="enp132s0np0"

. /mnt/tests/kernel/networking/common/include.sh
. /mnt/tests/kernel/networking/common/lib/lib_nc_sync.sh 
. /mnt/tests/kernel/networking/common/lib/lib_netperf_all.sh

. /mnt/tests/kernel/networking/openvswitch/offload/offload_topo_common.sh



vnic1=""
vnic2=""
vfr0=""
vfr1=""
vnic1_bus_info=""
vnic2_bus_info=""

vnic1_mac="e4:11:22:33:44:60"
vnic2_mac="e4:11:22:33:44:61"

NAY=yes
NIC_NUM=1
TOPO=nic
#NIC_DRIVER="mlx5_core"
NIC_DRIVER="nfp"

ovs="openvswitch-2.9.0-94.el7fdp.x86_64.rpm"
selinux="http://download-node-02.eng.bos.redhat.com/brewroot/packages/openvswitch-selinux-extra-policy/1.0/8.el7fdp/noarch/openvswitch-selinux-extra-policy-1.0-8.el7fdp.noarch.rpm"
dpdk="1811-2"

ovs_rpm=$ovs
sel_link=$selinux
dpdk_version=$dpdk


THOUGHPUT_64=9444460
THROUGHPUT_1500=1782998

frames="64"
flows="1 10"
policies="skip_sw skip_hw"

result_file="nfp_1PF1VF.log"
tc_result_file="tc_nfp_1PF1VF.log"

results=()
tc_results=()

topology="1pf1vf"
upload=${upload:- 'no'}
upload=$(echo "$upload" | awk '{print tolower($0)}')


function add_ovs_br() {
	ovs-vsctl add-br ovsbr0
	ip link set ovsbr0 up
	ovs-vsctl add-port ovsbr0 $nic -- set interface $nic ofport_request=1
	ovs-vsctl add-port ovsbr0 $vfr0 -- set interface $vfr0 ofport_request=2
	#ovs-vsctl add-port ovsbr0 $vfr1 -- set interface $vfr1 ofport_request=3
	ovs-vsctl show
}

function add_ovs_flows() {
	ovs-ofctl add-flow ovsbr0 in_port=1,actions=output:2
	ovs-ofctl add-flow ovsbr0 in_port=2,actions=output:1
	ovs-ofctl dump-ports-desc ovsbr0
	ovs-ofctl dump-flows ovsbr0
}

function add_tc_filter() {
	filter_policy=$1
	tc qdisc add dev $nic ingress
	tc filter add dev $nic protocol all parent ffff: flower $filter_policy src_mac 04:f4:bc:6a:8e:c0 action mirred egress redirect dev $vfr0
	tc filter show dev $nic ingress

	tc qdisc add dev $vfr0 ingress
	tc filter add dev $vfr0 protocol all parent ffff: flower $filter_policy src_mac 04:f4:bc:6a:8e:c0 action mirred egress redirect dev $nic
	tc filter show dev $vfr0 ingress
}

echo $nic
ip link set $nic up
ethtool -i $nic
ethtool -k $nic

#xena_change_speed 100
#netscout_xena_port=$(nfp_get_xena_port)
#my_netscout_port=$(get_netscout_port $nic)
#echo $netscout_xena_port $my_netscout_port
#Netscout_connect $netscout_xena_port $my_netscout_port



echo "-------------------Enabling VFs"
nfp_enable_vf $nic
ethtool -i $nic

echo $sel_link
echo $ovs_rpm

yum install -y $sel_link
local_ovs_install $ovs_rpm
add_ovs_br; add_ovs_flows

sleep 10
create_vm
sleep 666

virsh start master
virsh list --all

vmsh run_cmd master "cat /root/post_install.log"

echo "--------------------Editing VM Interfaces"
edit_nfp_vm_interfaces
sleep 20
virsh list --all
sleep 10


cmd_install_dpdk_vm=(
            {cd /root/dpdkrpms/ }
	    {cd $dpdk_version/ }
            {yum install -y dpdk* }
            {cd}
        )

vmsh cmd_set master "${cmd_install_dpdk_vm[*]}"
virsh reboot master
sleep 30

cmd_bind_nic_vm=(
            {/root/bind.sh ens3 ens8}
        )
rlRun 'vmsh cmd_set master "${cmd_bind_nic_vm[*]}"'

cmd_setup_vm=(
            {/root/one_gig_hugepages.sh 1}
            {cat /proc/meminfo}
        )
vmsh cmd_set master "${cmd_setup_vm[*]}"


echo "------------Starting Testpmd"
VMSH_PROMPT1="testpmd>" VMSH_NORESULT=1 VMSH_NOLOGOUT=1 vmsh run_cmd master "/root/testpmd.sh -n 2 -c 3 -q 1 -m 1024 -w 0000:00:03.0 -f io"

#WORKING COMMAND-
#17.11 command
#testpmd -l 0,1,2 -n4 --socket-mem 1024 -w 0000:00:03.0 -- --burst=64 -i --txqflags=0xf00 --rxd=2048 --txd=2048 --nb-cores=2 --rxq=1 --txq=1 --disable-rss --forward-mode=io --auto-start --port-topology=chained

#18.11 command
#testpmd -l 0,1,2 -n 4 -w 0000:00:03.0 --burst=64 -i --rxd=2048 --txd=2048 --nb-cores=2 --rxq=1 --txq=1 --disable-rss --forward-mode=io --auto-start


######### RUN TESTS #################



for frame in $frames; do for flow in $flows; do
	config_file=$flow'K_'$frame'_hwoffload.x2544'
	echo $config_file
	echo "------ HARDWARE OFFLOAD DISABLED $frame $flow"
	disable_hw_offload
	get_xena_config $config_file
	run_xena_traffic $config_file
	dis_result_xml='~/Xena2544ThroughputVerify/'$flow'K-'$frame'-hwoffload.xml'
	cat $dis_result_xml
	get_avg_latency $dis_result_xml dis_AvgLatency
	get_min_latency $dis_result_xml dis_MinLatency
	get_max_latency $dis_result_xml dis_MaxLatency
	get_fps $dis_result_xml dis_fps

	echo "------ HARDWARE OFFLOAD ENABLED $frame $flow"
	enable_hw_offload
	en_result_xml='~/Xena2544ThroughputVerify/'$flow'K-'$frame'-hwoffload.xml'
	cat $en_result_xml
	get_avg_latency $en_result_xml en_AvgLatency
        get_min_latency $en_result_xml en_MinLatency
        get_max_latency $en_result_xml en_MaxLatency
        get_fps $en_result_xml en_fps
	
	echo $result_file $frame $flow $en_fps $en_AvgLatency $en_MinLatency $en_MaxLatency $dis_fps $dis_AvgLatency $dis_MinLatency $dis_MaxLatency

done; done




####### CLEANUP

#Remove VM
echo "Removing VM"
virsh destroy master
rm -f /var/lib/libvirt/images/master.qcow2

#Remove VFs
echo "Removing VFs"
echo 0 > /sys/class/net/$nic/device/sriov_numvfs

#Remove OVS
echo "Removing OVS Bridge"
ovs-vsctl del-br ovsbr0


