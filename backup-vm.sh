#!/usr/bin/perl
# backup-vm.sh
#
# Creates the disk image and configuration for a new Xen virtual machine
#
# @version 0.1 20060803
# @author Jonathan Oxer <jon@ivt.com.au>
# @copyright 2006 Internet Vision Technologies <www.ivt.com.au>
####################################################################
# Do some initial setup of values to use
if($ARGV[0])
{
	$vm_name = $ARGV[0];
}
else
{
	print "Sorry, you need to specify a VM to back up\n";
	exit;
}

$storagepath = "/xenimages";
$vg_name      = "xenimages";


####################################################################
print "Loading snapshot device-mapper kernel module\n";
`modprobe dm-snapshot`;
print "done\n";

print "Creating backup mount point...";
my $command = "mkdir -p $storagepath/$vm_name.d/snapshot";
#print "\nc: $command\n";
`$command`;
print "done\n";

print "Creating the snapshot partition ...";
$vm_disksize = 5;
$vm_disksizemb = $vm_disksize * 1000;
my $command = "lvcreate -L${vm_disksizemb}M -s -n ${vm_name}-snapshot /dev/$vg_name/${vm_name}-root";
#print "\nc: $command\n";
`$command`;
print "done\n";

print "Mounting snapshot...";
my $command = "mount /dev/$vg_name/${vm_name}-snapshot $storagepath/$vm_name.d/snapshot/";
#print "\nc: $command\n";
`$command`;
print "done\n";
exit;

print "Mounting source filesystem...";
my $command = "mount /dev/$vg_name/guest $storagepath/guest/";
print "\nc: $command\n";
`$command`;
print "done\n";

print "Copying source filesystem to target filesystem...";
my $command = "cp -a $storagepath/guest/* $storagepath/$vm_name.d/mnt/";
print "\nc: $command\n";
`$command`;
print "done\n";

print "Creating the swap image...";
#my $command = "dd if=/dev/zero of=$storagepath/$vm_name.d/$vm_name-swap.img bs=1024k count=$vm_swapsize >/dev/null";
my $command = "lvcreate -L$vm_swapsize -n${vm_name}-swap $vg_name";
print "\nc: $command\n";
`$command`;
print "done\n";

print "Creating swap filesystem...";
my $command = "mkswap /dev/$vg_name/${vm_name}-swap";
print "c: $command\n";
`$command`;
print "done\n";

# Create Xen conf
print "Creating Xen config file...";
my $vm_xenconfig = "#  -*- mode: python; -*-
kernel = \"/boot/vmlinuz-2.6.16-xen\"
ramdisk = \"/boot/initrd.img-2.6.16-xen\"
memory = $vm_ram
name = \"$vm_name\"
vif = ['mac=$vm_mac,bridge=xenbr0']
disk = ['phy:$vg_name/${vm_name}-root,hda1,w','phy:$vg_name/${vm_name}-swap.img,hda2,w']
ip = \"$vm_ipaddress\"
netmask = \"$vm_netmask\"
gateway = \"$vm_gateway\"
hostname = \"$vm_name\"
root = \"/dev/hda1 ro\"
extra = \"4\"";
open (CONFIGFILE, ">$storagepath/$vm_name.d/$vm_name");
print CONFIGFILE $vm_xenconfig;
close (CONFIGFILE);
print "done\n";

# Create interfaces
print "Creating /etc/network/interfaces...";
$vm_netconfig = "# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto eth0
iface eth0 inet static
        address $vm_ipaddress
        netmask $vm_netmask
        gateway $vm_gateway
#        broadcast 1.0.1.255
#        dns-nameservers 192.168.0.1";
open (CONFIGFILE, ">$storagepath/$vm_name.d/mnt/etc/network/interfaces");
print CONFIGFILE $vm_netconfig;
close (CONFIGFILE);
print "done\n";

# Create hostname
print "Creating /etc/hostname...";
$vm_hostnameconfig = "$vm_name";
open (CONFIGFILE, ">$storagepath/$vm_name.d/mnt/etc/hostname");
print CONFIGFILE $vm_hostnameconfig;
close (CONFIGFILE);
print "done\n";

# Create hosts
print "Creating /etc/hosts...";
$vm_hostsconfig = "127.0.0.1       localhost localhost.localdomain
127.0.0.1       $vm_name
221.133.213.9	cache

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts";
open (CONFIGFILE, ">$storagepath/$vm_name.d/mnt/etc/hosts");
print CONFIGFILE $vm_hostsconfig;
close (CONFIGFILE);
print "done\n";

# Create symlink for Xen
#print "Creating config symlink...";
#my $command = "ln -s /xen-images/$vm_name/$vm_name /etc/xen/$vm_name";
#print "c: $command\n";
#`$command`;
#print "done\n";

# Unmount source and target
print "Unmounting source and target filesystems...";
my $command = "sync; umount $storagepath/$vm_name.d/mnt; umount $storagepath/guest";
`$command`;
print "done\n";


exit;

