#!/bin/bash

set -e

[ -f /etc/grml_cd ] || { echo "File /etc/grml_cd doesn't exist, not executing script to avoid data loss." >&2 ; exit 1 ; }

TARGET=/mnt

# if we notice an error then do NOT immediately return but provide
# user a chance to debug the VM
bailout() {
  echo "* Noticed problem during execution, sleeping for 9999 seconds to provide debugging option"
  sleep 9999
  echo "* Finally exiting with return code 1"
  exit 1
}
trap bailout ERR

echo "* Executing automated partition setup"
cat > /tmp/partition_setup.txt << EOF
disk_config sda disklabel:msdos bootable:1
primary / 800M- ext4 rw
EOF

export LOGDIR='/tmp/setup-storage'
mkdir -p $LOGDIR

export disklist=$(/usr/lib/fai/fai-disk-info | sort)
PATH=/usr/lib/fai:${PATH} setup-storage -f /tmp/partition_setup.txt -X

echo "* Making sure we use latest grml-debootstrap version"
apt-get update
apt-get -y install grml-debootstrap

# TODO - support testing the version provided by the ISO (without upgrading)
if [ -r /tmp/grml-debootstrap ] ; then
  echo "* Found /tmp/grml-debootstrap - considering for usage as main grml-debootstrap script"
  GRML_DEBOOTSTRAP="bash /tmp/grml-debootstrap"
else
  GRML_DEBOOTSTRAP=grml-debootstrap
fi

echo "* Installing Debian"
$GRML_DEBOOTSTRAP --hostname wheezy --release wheezy --target /dev/sda1 --grub /dev/sda --password grml --force 2>&1 | tee -a /tmp/grml-debootstrap.log

echo "* Mounting target system"
mount /dev/sda1 ${TARGET}

echo "* Installing make + gcc packages for Virtualbox Guest Additions"
chroot ${TARGET} apt-get -y install make gcc dkms

echo "* Installing Virtualbox Guest Additions"
isofile="${HOME}/VBoxGuestAdditions.iso"

KERNELHEADERS=$(basename $(find $TARGET/usr/src/ -maxdepth 1 -name linux-headers\* ! -name \*common) | sort -u -r -V | head -1)
if [ -z "$KERNELHEADERS" ] ; then
  echo "Error: no kernel headers found for building the VirtualBox Guest Additions kernel module." >&2
  exit 1
fi

KERNELVERSION=${KERNELHEADERS##linux-headers-}
if [ -z "$KERNELVERSION" ] ; then
  echo "Error: no kernel version could be identified." >&2
  exit 1
fi

cp /tmp/fake-uname.so "${TARGET}/tmp/fake-uname.so"
mkdir -p "${TARGET}/media/cdrom"
mountpoint "${TARGET}/media/cdrom" >/dev/null && umount "${TARGET}/media/cdrom"
mount -t iso9660 $isofile "${TARGET}/media/cdrom/"
UTS_RELEASE=$KERNELVERSION LD_PRELOAD=/tmp/fake-uname.so grml-chroot "$TARGET" /media/cdrom/VBoxLinuxAdditions.run --nox11 || true
tail -10 "${TARGET}/var/log/VBoxGuestAdditions.log"
umount "${TARGET}/media/cdrom/"

# work around regression in virtualbox-guest-additions-iso 4.3.10
if [ -d ${TARGET}/opt/VBoxGuestAdditions-4.3.10 ] ; then
  ln -s /opt/VBoxGuestAdditions-4.3.10/lib/VBoxGuestAdditions ${TARGET}/usr/lib/VBoxGuestAdditions
fi

echo "* Setting password for user root to 'vagrant'"
echo root:vagrant | chroot ${TARGET} chpasswd

echo "* Installing sudo package"
chroot ${TARGET} apt-get -y install sudo

echo "* Adding Vagrant user"
chroot ${TARGET} useradd -d /home/vagrant -m -u 1000 vagrant

echo "* Installing Vagrant ssh key"
mkdir -m 0700 -p ${TARGET}/home/vagrant/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" >> ${TARGET}/home/vagrant/.ssh/authorized_keys
chmod 0600 ${TARGET}/home/vagrant/.ssh/authorized_keys
chroot ${TARGET} chown vagrant:vagrant /home/vagrant/.ssh /home/vagrant/.ssh/authorized_keys

echo "* Setting up sudo configuration for user vagrant"
echo "vagrant ALL=(ALL) NOPASSWD: ALL" > ${TARGET}/etc/sudoers.d/vagrant

if [ -f ${TARGET}/etc/ssh/sshd_config ] && ! grep -q '^UseDNS' ${TARGET}/etc/ssh/sshd_config ; then
  echo "* Disabling UseDNS in sshd config"
  echo "UseDNS no" >> ${TARGET}/etc/ssh/sshd_config
fi

echo "* Cleaning up apt stuff"
chroot ${TARGET} apt-get clean
rm -f ${TARGET}/var/lib/apt/lists/*Packages \
      ${TARGET}/var/lib/apt/lists/*Release \
      ${TARGET}/var/lib/apt/lists/*Sources \
      ${TARGET}/var/lib/apt/lists/*Index* \
      ${TARGET}/var/lib/apt/lists/*Translation* \
      ${TARGET}/var/lib/apt/lists/*.gpg \
      ${TARGET}/var/cache/apt-show-versions/* \
      ${TARGET}/var/cache/debconf/*.dat-old \
      ${TARGET}/var/cache/apt/*.bin \
      ${TARGET}/var/lib/aptitude/pkgstates.old

echo "* Unmounting target system"
umount ${TARGET}

echo "* Checking for bats"
if dpkg --list bats >/dev/null 2>&1 ; then
  echo "* bats is already present, nothing to do."
else
  echo "* Installing bats"
  apt-get update
  apt-get -y install bats
  # dpkg -i /tmp/bats*deb
fi

echo "* Running tests to verify grml-debootstrap system"
bats /tmp/debian64.bats -t

echo "* Finished execution of $0"
