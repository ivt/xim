# Initial setup of Xen image environment
# Assumes a volume group called "xenimages" already exists


# Create the logical volume to store the guest image
lvcreate -L1000 -tguest xenimages
mkfs.ext3 /dev/xenimages/guest

mkdir /xenimages/mnt
mount -o loop /home/ivt/guest.img /xenimages/mnt

mkdir /xenimages/guest
mount /dev/xenimages/guest /xenimages/guest


