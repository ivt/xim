#!/usr/bin/perl
# create-vm.sh
#
# Creates the disk image and configuration for a new Xen virtual machine
#
# @version 0.1 20060803
# @version 0.2 20060905
# @author Jonathan Oxer <jon@ivt.com.au>
# @copyright 2006 Internet Vision Technologies <www.ivt.com.au>
####################################################################
$storagepath = "/xenimages";
$vg_name      = "xenimages";

# Prompt for user input for a bunch of settings for this VM
print "Name for VM: [web1] ";
chomp(my $vm_name = <>);
if($vm_name lt 0)
{
	$vm_name = "web1";
}

print "Size of disk image in GB: [5] ";
chomp (my $vm_disksize = <>);
if($vm_disksize lt 0)
{
	$vm_disksize = 5;
}

print "Size of swap space in MB: [200] ";
chomp (my $vm_swapsize = <>);
if($vm_swapsize lt 0)
{
	$vm_swapsize = 200;
}

print "Size of RAM allocation in MB: [192] ";
chomp (my $vm_ram = <>);
if($vm_ram lt 0)
{
	$vm_ram = 192;
}

print "IP address: [221.133.213.254] ";
chomp(my $vm_ipaddress = <>);
if($vm_ipaddress lt 0)
{
	$vm_ipaddress = "221.133.213.254";
}

print "Netmask: [255.255.255.0] ";
chomp(my $vm_netmask = <>);
if($vm_netmask lt 0)
{
	$vm_netmask = "255.255.255.0";
}

print "Gateway: [221.133.213.1] ";
chomp(my $vm_gateway = <>);
if($vm_gateway lt 0)
{
	$vm_gateway = "221.133.213.1";
}

# Figure out the MAC address based on the IP
# Split the dotted quads into array elements
@vm_mac = split(/\./, $vm_ipaddress);
# Make sure each element is padded to three digits so we have a 12-digit number
@vm_mac[0] = sprintf"%03d",@vm_mac[0];
@vm_mac[1] = sprintf"%03d",@vm_mac[1];
@vm_mac[2] = sprintf"%03d",@vm_mac[2];
@vm_mac[3] = sprintf"%03d",@vm_mac[3];
# Put the elements back together as one long string
$vm_mac = join("", @vm_mac);
# Chunk split the string into colon separated pairs of digits
$vm_mac = substr($vm_mac, 0, 2).":".substr($vm_mac, 2, 2).":".substr($vm_mac, 4, 2).":".substr($vm_mac, 6, 2).":".substr($vm_mac, 8, 2).":".substr($vm_mac, 10, 2);

# Show what values we're going to use
print "Values for the new VM will be:\n";
print " Name:       $vm_name\n";
print " Disk Size:  $vm_disksize GB\n";
print " Swap Size:  $vm_swapsize MB\n";
print " RAM Size:   $vm_ram MB\n";
print " IP Address: $vm_ipaddress\n";
print " Netmask:    $vm_netmask\n";
print " Gateway:    $vm_gateway\n";
print " MAC addr:   $vm_mac\n";
print "Continue? [Y|n]: ";
chomp(my $continue = <>);
if($continue lt 0)
{
	$continue = "y";
}
$continue =~ tr/A-Z/a-z/;
if($continue ne "y")
{
	print "OK, bailing out\n";
	exit 0;
}

#print "continuing\n";

print "Creating VM directory and mount point...";
my $command = "mkdir -p $storagepath/$vm_name.d/mnt";
print "c: $command\n";
`$command`;
print "done\n";

print "Creating the target root partition...";
$vm_disksizemb = $vm_disksize * 1000;
my $command = "lvcreate -L$vm_disksizemb -n${vm_name}-root $vg_name";
print "\nc: $command\n";
`$command`;
print "done\n";

print "Creating root filesystem on target root partition...";
my $command = "mkfs.ext3 /dev/$vg_name/${vm_name}-root";
print "\nc: $command\n";
`$command`;
print "done\n";

print "Mounting target root partition...";
my $command = "mount /dev/$vg_name/${vm_name}-root $storagepath/$vm_name.d/mnt/";
print "\nc: $command\n";
`$command`;
print "done\n";

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
ramdisk = \"/boot/initrd-2.6.16-xen.img\"
memory = $vm_ram
name = \"$vm_name\"
vif = ['mac=$vm_mac,bridge=xenbr0']
disk = ['phy:$vg_name/${vm_name}-root,hda1,w','phy:$vg_name/${vm_name}-swap,hda2,w']
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

