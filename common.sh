# ==== OVS Offload common functions ====


# To Update xena module speed
function xena_change_speed() {
    speed=$1

    if [ -d "~/temp/Xena-VSPerf" ]; then
        pushd ~/temp/Xena-VSPerf/tools/pkt_gen/xena
        python run_xena.py --run module --speed $speed
        popd
    else
        if [ ! -d "~/temp" ]; then mkdir ~/temp; fi
        pushd ~/temp
        yum install -y git
        git clone https://github.com/ctrautma/Xena-VSPerf.git
        cd Xena-VSPerf/tools/pkt_gen/xena/
        python run_xena.py --run module --speed $speed
	popd
    fi
}


get_xena_new_speed() {
   if [ $NIC_DRIVER == "mlx5_core" ]; then
       xena_speed=100
   elif [ $NIC_DRIVER == "nfp" ]; then
       xena_speed=25
   fi
    echo $xena_speed
}

# To make Netscout connections
function Netscout_connect() {
    port1=$1
    port2=$2

    if [ -d "~/temp/NetScout" ]; then 
        pushd ~/temp/NetScout
        python NSConnect.py --connect $port1 $port2
        popd
    else
        if [ ! -d "~/temp" ]; then mkdir ~/temp; fi
        pushd ~/temp
        yum install -y git
        git clone https://github.com/ctrautma/NetScout.git
        cd NetScout
        wget -O settings.cfg http://netqe-infra01.knqe.lab.eng.bos.redhat.com/NSConn/bos_3200.cfg
        python NSConnect.py --connect $port1 $port2
        cd ..
        popd
    fi
}

function Netscout_disconnect() {
    port1=$1
    port2=$2

    if [ -d "~/temp/NetScout" ]; then
        pushd ~/temp/NetScout
        python NSConnect.py --disconnect $port1 $port2
        popd
    else
        if [ ! -d "~/temp" ]; then mkdir ~/temp; fi
        pushd ~/temp
        yum install -y git
        git clone https://github.com/ctrautma/NetScout.git
        cd NetScout
        wget -O settings.cfg http://netqe-infra01.knqe.lab.eng.bos.redhat.com/NSConn/bos_3200.cfg
        python NSConnect.py --disconnect $port1 $port2
        cd ..
        popd
    fi
}


function get_netscout_port() {
    host=$(hostname | cut -d '.' -f 1 | awk '{print toupper($0)}')
    if [[ ( $host == "NETQE12"  && $NIC_DRIVER == "mlx5_core" ) ]]; then 
	NS_port="NETQE12_P6P1"
    elif [[ ( $host == "NETQE12"  && $NIC_DRIVER == "nfp" ) ]]; then
	NS_port="NETQE12_ENP132S0NP0"
    elif [[ ( $host == "NETQE28"  && $NIC_DRIVER == "mlx5_core" ) ]]; then 
        NS_port="NETQE28_P2P1"
    else
	NS_port=$(get_my_netscout_port $1)
    fi
    echo $NS_port
}

function get_my_netscout_port() {
    nic=$(echo $1 | awk '{print toupper($0)}')
    host=$(hostname | cut -d '.' -f 1 | awk '{print toupper($0)}')
    NS_port=$host"_"$nic
    echo $NS_port
}

mlx_get_xena_port() {
    if [ $NIC_DRIVER == "mlx5_core" ]; then
        xena_port="XENA_100_M9P0"
    fi
    echo $xena_port
}

nfp_get_xena_port() {
    if [ $NIC_DRIVER == "nfp" ]; then
        xena_port="XENA_25_M9P0"
    fi
    echo $xena_port
}


# To modify VM XML
function mlx_modify_vm_xml() {
    bus_info1=$1
    bus_info2=$2
    vm_xml="mlx_master.xml"

    search1="<address type='pci' domain='0x0000' bus='0x5f' slot='0x00' function='0x2'/>"
    search2="<address type='pci' domain='0x0000' bus='0x5f' slot='0x00' function='0x3'/>"

    replace1=$(get_replace $bus_info1)
    replace2=$(get_replace $bus_info2)
    echo $replace1
    echo $replace2

    sed -i "s~${search1}~${replace1}~g" $vm_xml
    sed -i "s~${search2}~${replace2}~g" $vm_xml
}


function nfp_modify_vm_xml() {
    bus_info1=$1
    bus_info2=$2
    vm_xml="nfp_master.xml"

    search1="<address type='pci' domain='0x0000' bus='0x82' slot='0x08' function='0x0'/>"
    search2="<address type='pci' domain='0x0000' bus='0x82' slot='0x08' function='0x1'/>"

    replace1=$(get_replace $bus_info1)
    replace2=$(get_replace $bus_info2)
    echo $replace1
    echo $replace2

    sed -i "s~${search1}~${replace1}~g" $vm_xml
    sed -i "s~${search2}~${replace2}~g" $vm_xml
}


function get_replace() {
    bus_info=$1
    domain=$(echo "0x"$(echo $bus_info | cut -d ':' -f 1))
    bus=$(echo "0x"$(echo $bus_info | cut -d ':' -f 2))
    slot=$(echo "0x"$(echo $bus_info | cut -d ':' -f 3 | cut -d '.' -f 1))
    function=$(echo "0x"$(echo $bus_info | cut -d ':' -f 3 | cut -d '.' -f 2))

    replace="<address type='pci' domain='$domain' bus='$bus' slot='$slot' function='$function'/>"
    echo $replace

}


# Get Virtual Function names
function get_nic_vfs(){
        nic=$1
        NIC_DIR="/sys/class/net"
        link_dir=$( readlink ${NIC_DIR}/$nic )
        VF_NAMES=""
        if [ -d "${NIC_DIR}/$nic/device" -a ! -L "${NIC_DIR}/$nic/device/physfn" ]; then
                declare -a VF_PCI_BDF
                declare -a VF_INTERFACE
                k=0
                for j in $( ls "${NIC_DIR}/$nic/device" ) ;
                do
                        if [[ "$j" == "virtfn"* ]]; then
                                VF_PCI=$( readlink "${NIC_DIR}/$nic/device/$j" | cut -d '/' -f2 )
                                VF_PCI_BDF[$k]=$VF_PCI
                                #get the interface name for the VF at this PCI Address
                                for iface in $( ls $NIC_DIR );
                                do
                                        link_dir=$( readlink ${NIC_DIR}/$iface )
                                        if [[ "$link_dir" == *"$VF_PCI"* ]]; then
                                                VF_INTERFACE[$k]=$iface
                                                VF_NAMES=$VF_NAMES" "$iface

                                        fi
                                done
                                ((k++))
                        fi
                done
        fi
        echo $VF_NAMES
        vnic1=$(echo $VF_NAMES | awk '{print $1}')
        vnic2=$(echo $VF_NAMES | awk '{print $2}')
}

# Mellanox Enable VFs
function mlx_enable_vf() {
    nic=$1
    bus_info=$(ethtool -i $nic | grep bus-info | awk '{print $2}')
    bus_info1=$(echo $bus_info | cut -d '.' -f 1)
    driver=$(ethtool -i $nic | grep driver | awk '{print $2}')

    #mlx_cleanup $nic

    echo 2 > /sys/class/net/$nic/device/sriov_numvfs
    sleep 5
    cat /sys/class/net/$nic/device/sriov_numvfs
    get_nic_vfs $nic
    echo $vnic1 $vnic2

    #We can assign IP address to VFs if we want to control them
    ip link set $nic vf 0 mac $vnic1_mac
    ip link set $nic vf 1 mac $vnic2_mac
    
    ip link show dev $nic
    ip a | grep -A1 $nic

    #echo 0 > /sys/class/net/$nic/device/sriov_numvfs

    vnic1_bus_info=$(ethtool -i $vnic1 | grep 'bus-info' | awk '{print $2}')
    vnic2_bus_info=$(ethtool -i $vnic2 | grep 'bus-info' | awk '{print $2}')
    echo $vnic1_bus_info $vnic2_bus_info

    echo $vnic1_bus_info > /sys/bus/pci/drivers/$driver/unbind
    echo $vnic2_bus_info > /sys/bus/pci/drivers/$driver/unbind
    sleep 3
	

#NEED TO CONFIGURE REPRESENTER HERE TO ADD TO OVS BRIDGE
    
    switch_id=$(ip -d link show dev $nic | sed -n -e 's/^.*switchid //p' | awk '{print $1}')
    echo $switch_id

    #after adding card to switch dev mode, get switch_id
    echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{phys_switch_id}=="'"$switch_id"'", ATTR{phys_port_name}!="",    NAME="'"$nic"_sd'_$attr{phys_port_name}"' > /etc/udev/rules.d/ovs_offload.rules


    #Attributes mentioned in above rule can be found at- ls devices/virtual/net/
    #To Reload the rule-
    udevadm control --reload
    udevadm trigger
    udevadm trigger -vv | grep $bus_info1

    devlink dev eswitch set pci/$bus_info mode switchdev

    #devlink dev eswitch set pci/$bus_info inline-mode transport
	#Above command commented out because it fails on connectx5 and its set by default for this card

    ip link set $nic up

    vfr0="$nic"_sd_0
    vfr1="$nic"_sd_1

}

# Mellanox delete VFs
function mlx_cleanup(){
    nic=$1
    bus_info=$(ethtool -i $nic | grep bus-info | awk '{print $2}')
    bus_info1=$(echo $bus_info | cut -d '.' -f 1)
    driver=$(ethtool -i $nic | grep driver | awk '{print $2}')

    echo 2 > /sys/class/net/$nic/device/sriov_numvfs
    sleep 5
    cat /sys/class/net/$nic/device/sriov_numvfs
    get_nic_vfs $nic
    echo $vnic1 $vnic2

    #We can assign IP address to VFs if we want to control them
    ip link set $nic vf 0 mac $vnic1_mac
    ip link set $nic vf 1 mac $vnic2_mac
    
    ip link show dev $nic
    ip a | grep -A1 $nic

    echo 0 > /sys/class/net/$nic/device/sriov_numvfs
}

# Switch Netronome card firmware
function switch_nfp_firmware() {
    APP=${1:-flower}
    FWDIR=${2:-/lib/firmware/netronome/}
    cd ${FWDIR}
    for FW in *.nffw; do
      if [ -L ${FW} ]; then
        ln -sf ${APP}/${FW} ${FW}
      fi
    done
    cd
    rmmod nfp; sleep 3; modprobe nfp
}

# Netronome enable VFs
function nfp_enable_vf() {
    nic=$1
    bus_info=$(ethtool -i $nic | grep bus-info | awk '{print $2}')
    bus_info1=$(echo $bus_info | cut -d '.' -f 1)
    bus_info2=$(echo $bus_info | cut -d ':' -f2,3)
    driver=$(ethtool -i $nic | grep driver | awk '{print $2}')
    echo $bus_info $bus_info1 $bus_info2 $driver

    switch_nfp_firmware flower
    ethtool -i $nic

    ip link set $nic up
    echo 2 > /sys/bus/pci/devices/0000:$(lspci -d 19ee:4000 | cut -d ' ' -f 1 | grep $bus_info2)/sriov_numvfs
    cat /sys/bus/pci/devices/0000:$(lspci -d 19ee:4000 | cut -d ' ' -f 1 | grep $bus_info2)/sriov_numvfs
    
    echo "#Getting nic VFs..."
    get_nic_vfs $nic

    ip link set $nic vf 0 mac $vnic1_mac
    ip link set $nic vf 1 mac $vnic2_mac
    ip link show dev $nic
    ip a | grep -A1 $nic

    vnic1_bus_info=$(ethtool -i $vnic1 | grep 'bus-info' | awk '{print $2}')
    vnic2_bus_info=$(ethtool -i $vnic2 | grep 'bus-info' | awk '{print $2}')
    echo $vnic1_bus_info $vnic2_bus_info

    echo $vnic1_bus_info > /sys/bus/pci/drivers/$driver/unbind
    echo $vnic2_bus_info > /sys/bus/pci/drivers/$driver/unbind
    sleep 3
    
    echo "#Displaying Additional Information..."
    dmesg | grep nfp | grep Representor
    lshw -c network -businfo

    vfr0=$(dmesg | grep 'VF0 Representor' | rev | awk '{print $2}' | rev | cut -d "(" -f2 | cut -d ")" -f1)
    vfr1=$(dmesg | grep 'VF1 Representor' | rev | awk '{print $2}' | rev | cut -d "(" -f2 | cut -d ")" -f1)
    echo $vfr0 $vfr1
}

# Netronome delete VFs


# Enable Hardware Offload
function enable_hw_offload() {
  # Enable tc offloading on the interfaces
    ethtool -K $nic hw-tc-offload on
    ethtool -K $vfr0 hw-tc-offload on
    ethtool -K $vfr1 hw-tc-offload on

  # Make sure OVS is up
    systemctl restart openvswitch.service
  # Enable ovs hw-offload
    ovs-vsctl set Open_vSwitch . other_config:hw-offload=true

  # And restart it again so it initializes with hw-offload=true
    systemctl restart openvswitch.service

  # After here, it should be ready to roll.
    ip l s $nic up
    ovs-vsctl get Open_vSwitch . other_config
    add_ovs_flows
}


# Disable Hardware Offload
function disable_hw_offload() {
  # Disable tc offloading on the interfaces
    ethtool -K $nic hw-tc-offload off
    ethtool -K $vfr0 hw-tc-offload off
    ethtool -K $vfr1 hw-tc-offload off

  # Make sure OVS is up
    systemctl restart openvswitch.service

  # Disable ovs hw-offload
    ovs-vsctl set Open_vSwitch . other_config:hw-offload=false

  # And restart it again so it initializes with hw-offload=true
    systemctl restart openvswitch.service

  # After here, it should be ready to roll.
    ip l s $nic up
    ovs-vsctl get Open_vSwitch . other_config
    add_ovs_flows
}

# Create VM
function create_vm() {
    #yum -y install bridge-utils qemu-kvm libvirt virt-install
    cd
    git clone https://github.com/ctrautma/VSPerfBeakerInstall.git
    chmod +x ~/VSPerfBeakerInstall/vmcreate.sh
    rhel_version=$(cut -f1 -d. /etc/redhat-release | sed 's/[^0-9]//g')
    if [[ $rhel_version == 8 ]]; then
    	location="http://download-node-02.eng.bos.redhat.com/released/RHEL-8/8.0-Beta/BaseOS/x86_64/os"
        ./VSPerfBeakerInstall/vmcreate.sh -c 3 -d -l $location
    else
        MYCOMPOSE=`cat /etc/yum.repos.d/beaker-Server.repo | grep baseurl | cut -c9-`
        ./VSPerfBeakerInstall/vmcreate.sh -c 3 -l $MYCOMPOSE -d
    fi
    sleep 3
    virsh start master
    virsh list --all
    sleep 30
    
}

#Edit Mellanox VM interfaces
function edit_mlx_vm_interfaces() {
	virsh shutdown master
	sleep 30
	wget netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/mlx_master.xml 
	mlx_modify_vm_xml $vnic1_bus_info $vnic2_bus_info
	virsh undefine master
	sleep 30
	cat mlx_master.xml
	virsh define mlx_master.xml
	sleep 30
	virsh list --all
	ip link set $nic up
	virsh start master
	sleep 30
}


#Edit Netronome VM interfaces
function edit_nfp_vm_interfaces() {
	virsh shutdown master
	sleep 30
	wget netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/nfp_master.xml 
	nfp_modify_vm_xml $vnic1_bus_info $vnic2_bus_info
	virsh undefine master
	sleep 30
	cat nfp_master.xml
	virsh define nfp_master.xml
	sleep 30
	virsh list --all
	ip link set $nic up
	#ip link set $inface up
	sleep 3
	virsh start master
	sleep 30
	virsh list --all
}


# To get link of OVS rpm
function get_ovs_rpm_link() {
        local ovs_version=$1
        local part0="http://download-node-02.eng.bos.redhat.com/brewroot/packages"
        local part1=$(echo $ovs_version | cut -d '-' -f 1)
        local part2=$(echo $ovs_version | cut -d '-' -f 2)
        local part3=$(echo $ovs_version | cut -d '-' -f 3 | rev | cut -d '.' -f 3- | rev)
        local part4=$(echo $ovs_version | cut -d '-' -f 3 | rev | cut -d '.' -f 2 | rev)
        openvswitch_rpm="$part0/$part1/$part2/$part3/$part4/$ovs_version"
        echo  $openvswitch_rpm
}

# To install OVS
function local_ovs_install()
{
	ovs_rpm=$1
	ovs_rpm_link=$(get_ovs_rpm_link $ovs_rpm)
	if [ $# -eq 1 ]; then sudo yum install -y openssl; sudo rpm -ivh $ovs_rpm_link; systemctl start openvswitch.service && systemctl enable openvswitch.service;
	else echo "Need one paramter: Ovs rpm to use";
	fi
}


# To transfer ascii file from xena
function ftp_file_transfer_ascii(){
	filename=$1
	local_location="."
	if [ "$#" -eq 2 ]; then
		local_location=$2
	fi
	HOST='10.19.188.65'
	USER='user2'
	PASSWD='xena'
	ftp -n -v $HOST << EOT
	ascii
	user $USER $PASSWD
	lcd $local_location
	get $filename
	bye
EOT
}

# To transfer binary file from xena
function ftp_file_transfer_bin(){
	filename=$1
	local_location="."
	if [ "$#" -eq 2 ]; then
		local_location=$2
	fi
	HOST='10.19.188.65'
	USER='user2'
	PASSWD='xena'
	ftp -n -v $HOST << EOT
	bin
	user $USER $PASSWD
	lcd $local_location
	get $filename
	bye	
EOT
}


# To install mono
function mono_install_rhel7(){
    echo "start to install mono rpm..."
    yum install -y yum-utils
    rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
    yum-config-manager --add-repo http://download.mono-project.com/repo/centos/
    yum -y install mono-complete-5.8.0.127-0.xamarin.3.epel7.x86_64
    yum-config-manager --disable download.mono-project.com_repo_centos_
    cd
}


function mono_install_rhel8(){
    PKG_MONO_SRC=${PKG_MONO_SRC:-"http://netqe-bj.usersys.redhat.com/share/tools/mono-5.8.0.127.src.tar.bz2"}
    PKG_LIBGDIPLUS_SRC=${PKG_LIBGDIPLUS_SRC:-"http://netqe-bj.usersys.redhat.com/share/tools/libgdiplus_20181012.src.zip"}
    PKG_MONO_AFTER_MAKE=${PKG_MONO_AFTER_MAKE:-"http://netqe-bj.usersys.redhat.com/share/tools/mono-5.8.0.127.rhel8.tar.tgz"}
    PKG_LIBGDIPLUS_AFTER_MAKE=${PKG_LIBGDIPLUS_AFTER_MAKE:-"http://netqe-bj.usersys.redhat.com/share/tools/libgdiplus_20181012.rhel8.tar.tgz"}
    yum install -y unzip libtool gcc-c++
    yum -y install http://download-node-02.eng.bos.redhat.com/brewroot/packages/giflib/5.1.4/2.el8/x86_64/giflib-5.1.4-2.el8.x86_64.rpm

    (
      echo [latest-RHEL8-AppStream]
      echo name=AppStream
      echo baseurl=http://download.eng.pek2.redhat.com/pub/rhel/rel-eng/latest-RHEL-8.%2A/compose/AppStream/x86_64/os/
      echo enabled=1
      echo gpgcheck=0
      echo skip_if_unavailable=1
    ) > /etc/yum.repos.d/rhel8_AppStream.repo

    cat << EOF >/etc/yum.repos.d/beaker-postrepo0.repo
[beaker-postrepo0]
name=beaker-postrepo0
baseurl=http://download.eng.pek2.redhat.com/nightly/latest-BUILDROOT-8-RHEL-8/compose/Buildroot/x86_64/os
enabled=1
gpgcheck=0
skip_if_unavailable=1
EOF

    rpm -q cmake &>/dev/null || yum -y install cmake
    rpm -q cairo-devel &/dev/null || yum -y install cairo-devel
    rpm -q libjpeg-turbo-devel &>/dev/null || yum -y install libjpeg-turbo-devel
    rpm -q libtiff-devel &>/dev/null || yum -y install libtiff-devel
    rpm -q giflib-devel &>/dev/null || yum -y install giflib-devel

    mkdir -p libgdiplus
    pushd libgdiplus &>/dev/null
    wget ${PKG_LIBGDIPLUS_SRC}
    unzip *.zip
    pushd libgdiplus-* &>/dev/null
    ./autogen.sh 
    make -j 8
    make install
    popd &>/dev/null
    popd &>/dev/null

    mkdir -p mono
    pushd mono &>/dev/null
    wget ${PKG_MONO_SRC}
    tar xvf mono-*.tar.bz2 
    pushd mono-*/ &>/dev/null
    ./configure 
    make -j 8
    make install
    popd &>/dev/null
    popd &>/dev/null
}

function local_mono_install(){
   rhel_version=$(cut -f1 -d. /etc/redhat-release | sed 's/[^0-9]//g')
    if [[ $rhel_version == 8 ]]; then
        mono_install_rhel8
    else
       mono_install_rhel7
    fi 
}


# Set up to automate xena traffic
function setup_automate_xena(){
    echo "Cloning Xena2544ThroughputVerify"
    cd
    git clone https://github.com/ctrautma/Xena2544ThroughputVerify.git
    cd Xena2544ThroughputVerify

    echo "Getting Xena2544.exe file"
    #ftp_file_transfer_bin Xena2544.exe
    wget http://netqe-infra01.knqe.lab.eng.bos.redhat.com/Xena2544.exe
}

# To get xena config file
function get_xena_config() {
    config_file=$1
    cd ~/Xena2544ThroughputVerify
    wget netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/$config_file
    cd
}

# To start xena traffic
function run_xena_traffic() {
    config_file=$1
    cd ~/Xena2544ThroughputVerify
    python XenaVerify.py -f $config_file -l 600 -r 10 -t 120
}


# CPU partitioning
function cpu_partitioning(){
    NIC1=$1
    NIC1_PCI_ADDR=`ethtool -i $NIC1 | awk /bus-info/ | awk {'print $2'}`
    NICNUMA=`cat /sys/class/net/$NIC1/device/numa_node`

    # Isolated CPU list
    ISOLCPUS=`lscpu | grep "NUMA node$NICNUMA" | awk '{print $4}'`

    if [[ `echo $ISOLCPUS | awk /'^0,'/ ` ]]
        then
        ISOLCPUS=`echo $ISOLCPUS | cut -c 3-`
    fi

    yum install -y tuned-profiles-cpu-partitioning
    echo -e "isolated_cores=$ISOLCPUS" >> /etc/tuned/cpu-partitioning-variables.conf
    tuned-adm profile cpu-partitioning

    rhel_version=$(cut -f1 -d. /etc/redhat-release | sed 's/[^0-9]//g')
    if [[ $rhel_version == 8 ]]; then
      kernelopts=$(grub2-editenv - list | grep kernelopts | sed -e 's/kernelopts=//g' -e 's/[^ ]*iommu[^ ]*//g' -e 's/[^ ]*hugepages[^ ]*//g')
      grub2-editenv - set kernelopts="$kernelopts intel_iommu=on iommu=pt default_hugepagesz=1GB hugepagesz=1G hugepages=24"
      cat /boot/grub2/grubenv 2>/dev/null
      cat /boot/efi/EFI/redhat/grubenv 2>/dev/null
    else  
      sed -i 's/\(GRUB_CMDLINE_LINUX.*\)"$/\1/g' /etc/default/grub
      sed -i "s/GRUB_CMDLINE_LINUX.*/& nohz=on default_hugepagesz=1G hugepagesz=1G hugepages=24 intel_iommu=on iommu=pt \"/g" /etc/default/grub
      grub2-mkconfig -o /boot/grub2/grub.cfg
    fi
    #reboot
}

# Install required packages
function packages_install() {
	yum install -y git wget tcl nano lsof tk perl
        yum install -y gcc-c++ glibc-devel gcc zlib-devel
        yum install -y qemu-kvm libvirt virt-install
	yum install -y bridge-utils net-tools pciutils
	yum install -y screen tuna
	yum install -y ftp
}

# Install QEMU
function qemu_install() {
    cat <<EOT >> /etc/yum.repos.d/osp8-rhel.repo
[osp8-rhel7]
name=osp8-rhel7
baseurl=http://download.lab.bos.redhat.com/rel-eng/OpenStack/8.0-RHEL-7/latest/RH7-RHOS-8.0/x86_64/os/
enabled=1
gpgcheck=0
skip_if_unavailable=1
EOT

    yum install -y qemu-kvm
    yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/seabios/1.10.2/3.el7_4.1/noarch/seabios-bin-1.10.2-3.el7_4.1.noarch.rpm
    yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/seabios/1.10.2/3.el7_4.1/noarch/seavgabios-bin-1.10.2-3.el7_4.1.noarch.rpm
    yum install -y http://download-node-02.eng.bos.redhat.com/brewroot/packages/ipxe/20170123/1.git4e85b27.el7_4.1/noarch/ipxe-roms-qemu-20170123-1.git4e85b27.el7_4.1.noarch.rpm

    mkdir qemu
    cd qemu
    wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-img-rhev-2.9.0-16.el7_4.13.x86_64.rpm
    wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-kvm-common-rhev-2.9.0-16.el7_4.13.x86_64.rpm
    wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-kvm-rhev-2.9.0-16.el7_4.13.x86_64.rpm
    wget http://download-node-02.eng.bos.redhat.com/brewroot/packages/qemu-kvm-rhev/2.9.0/16.el7_4.13/x86_64/qemu-kvm-tools-rhev-2.9.0-16.el7_4.13.x86_64.rpm
    rpm -Uvh *
    cd ..
}

# To get average latency
function get_avg_latency(){
    local xml_file=$1
    local avgLatency=$2
    avg_latency=$(awk '{for(i=1;i<=NF;i++){if($i~/^AvgLatency/) print $i}}' $xml_file | cut -d "\"" -f 2)
    eval $avgLatency="'$avg_latency'"
}

# To get minimum latency
function get_min_latency(){
    local xml_file=$1
    local minLatency=$2
    min_latency=$(awk '{for(i=1;i<=NF;i++){if($i~/^MinLatency/) print $i}}' $xml_file | cut -d "\"" -f 2)
    eval $minLatency="'$min_latency'"
}

# To get maximum latency
function get_max_latency(){
    local xml_file=$1
    local maxLatency=$2
    max_latency=$(awk '{for(i=1;i<=NF;i++){if($i~/^MaxLatency/) print $i}}' $xml_file | cut -d "\"" -f 2)
    eval $maxLatency="'$max_latency'"
}

# To get FPS
function get_fps(){
    xml_file=$1
    local fps=$2
    fpers=$(awk '{for(i=1;i<=NF;i++){if($i~/^PortRxPps/) print $i}}' $xml_file | cut -d "\"" -f 2 | cut -d '.' -f 1)
    eval $fps="'$fpers'"
}

# To add to log file
function add_to_log_file(){
    result_file=${1}
    frame_size=$2
    flow_count=$3
    en_fps=$4
    en_avglatency=$5
    en_minlatency=$6
    en_maxlatency=$7
    dis_fps=${8}
    dis_avglatency=${9}
    dis_minlatency=${10}
    dis_maxlatency=${11}
    
    title_format="%100s\n"
    title_val_format="%-20s %-20s\n"
    log_format="%-20s %-20s %-20s %-20s %-20s\n"

    printf "$title_format" "" |tee -a $result_file
    printf "$title_format" "" | tee -a $result_file
    printf "$title_val_format" "FRAME SIZE=$frame_size" "FLOWS=$flow_count""K" | tee -a $result_file
    printf "$title_format" "===================================================================================================" | tee -a $result_file
    printf "$log_format" "" "FPS" "AvgLatency" "MinLatency" "MaxLatency" | tee -a $result_file
    printf "$log_format" "Enabled:" "$en_fps" "$en_avglatency" "$en_minlatency" "$en_maxlatency" | tee -a $result_file
    printf "$log_format" "Disabled:" "$dis_fps" "$dis_avglatency" "$dis_minlatency" "$dis_maxlatency" | tee -a $result_file
    printf "$title_format" "===================================================================================================" | tee -a $result_file
}


# To upload results to Google sheet
function upload_to_googlesheet(){
    topology=${1}
    driver=${2}
    ovs_rpm=${3}
    results=${4}
    resultsheet=$(echo "Offload_Performance_OVS_"$(echo $ovs_rpm | cut -d '-' -f 2,3 | cut -d '.' -f 1,2,3,4))

    easy_install pip
    pip install --upgrade google-api-python-client oauth2client

    git clone https://github.com/AmitSupugade/ovsqe_results.git
    cd ovsqe_results
    wget http://netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/token.json
    wget http://netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/client_secret.json

    rlRun -l 'python OffloadResult.py --result $resultsheet --ovs $ovs_rpm --topo $topology --driver $driver --data "${results[@]}"'
    cd ..
}



### TC POLICY Functions ###
function upload_tc_to_googlesheet() {
    topology=${1}
    driver=${2}
    ovs_rpm=${3}
    tc_results=${4}
    tc_resultsheet=$(echo "Offload_Performance_OVS_TC_POLICY_"$(echo $ovs_rpm | cut -d '-' -f 2,3 | cut -d '.' -f 1,2,3,4))

    if [ -d "~/ovsqe_results" ]; then
        cd ovsqe_results
        rlRun -l 'python TcPolicyResult.py --result $tc_resultsheet --ovs $ovs_rpm --topo $topology --driver $driver --data "${tc_results[@]}"'
        cd
    else
	easy_install pip
    	pip install --upgrade google-api-python-client oauth2client

    	git clone https://github.com/AmitSupugade/ovsqe_results.git
    	cd ovsqe_results
    	wget http://netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/token.json
    	wget http://netqe-infra01.knqe.lab.eng.bos.redhat.com/ovs_offload/client_secret.json

    	rlRun -l 'python TcPolicyResult.py --result $tc_resultsheet --ovs $ovs_rpm --topo $topology --driver $driver --data "${tc_results[@]}"'
    	cd ..
    fi
}

function enable_tc_offload() {
    tc_policy=$1
    
    ethtool -K $nic hw-tc-offload on
    ethtool -K $vfr0 hw-tc-offload on
    ethtool -K $vfr1 hw-tc-offload on

    systemctl restart openvswitch.service
    
    #Enable ovs hw-offload
    ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
    ovs-vsctl set Open_vSwitch . other_config:tc-policy=$tc_policy

    systemctl restart openvswitch.service

    ip l s $nic up
    ovs-vsctl get Open_vSwitch . other_config
    add_tc_filter $tc_policy
}

function disable_tc_offload() {
    tc_policy=$1
    
    ethtool -K $nic hw-tc-offload off
    ethtool -K $vfr0 hw-tc-offload off
    ethtool -K $vfr1 hw-tc-offload off

    systemctl restart openvswitch.service

    #Disable ovs hw-offload
    ovs-vsctl set Open_vSwitch . other_config:hw-offload=false

    systemctl restart openvswitch.service

    ip l s $nic up
    ovs-vsctl get Open_vSwitch . other_config
    add_tc_filter $tc_policy
}

# To add to log file
function add_tc_to_log_file(){
    tc_result_file=${1}
    frame_size=$2
    flow_count=$3
    en_fps=$4
    en_avglatency=$5
    en_minlatency=$6
    en_maxlatency=$7
    dis_fps=${8}
    dis_avglatency=${9}
    dis_minlatency=${10}
    dis_maxlatency=${11}
    tc_policy=${12}
    
    title_format="%100s\n"
    title_val_format="%-20s %-20s %-20s\n"
    log_format="%-20s %-20s %-20s %-20s %-20s\n"

    printf "$title_format" "" |tee -a $tc_result_file
    printf "$title_format" "" | tee -a $tc_result_file
    printf "$title_val_format" "POLICY=$tc_policy" "FRAME SIZE=$frame_size" "FLOWS=$flow_count""K" | tee -a $tc_result_file
    printf "$title_format" "===================================================================================================" | tee -a $tc_result_file
    printf "$log_format" "" "FPS" "AvgLatency" "MinLatency" "MaxLatency" | tee -a $tc_result_file
    printf "$log_format" "Enabled:" "$en_fps" "$en_avglatency" "$en_minlatency" "$en_maxlatency" | tee -a $tc_result_file
    printf "$log_format" "Disabled:" "$dis_fps" "$dis_avglatency" "$dis_minlatency" "$dis_maxlatency" | tee -a $tc_result_file
    printf "$title_format" "===================================================================================================" | tee -a $tc_result_file
}
