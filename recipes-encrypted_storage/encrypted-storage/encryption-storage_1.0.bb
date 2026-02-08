SUMMARY = "Install disk encryption keys and disk mounting script"
DESCRIPTION = "This recipe installs encryption keys and a script for managing encrypted partitions."
LICENSE = "CLOSED"
AUTHOR = "Ammar Younas <muhammadammar.younas@arcelik.com>"
PR = "r0"

# Define the source URI for your key files and script
SRC_URI = "file://luks_key.bin.enc \
           file://mount_encrypted_partition.sh"

RDEPENDS:${PN} += "cryptsetup lvm2 e2fsprogs bash"  

do_install() {
    
    install -d ${D}${sysconfdir}/keys
    install -d ${D}/usr/local/bin
    
    install -m 0600 ${WORKDIR}/luks_key.bin.enc ${D}${sysconfdir}/keys/luks_key.bin.enc
    install -m 0755 ${WORKDIR}/mount_encrypted_partition.sh ${D}/usr/local/bin/mount_encrypted_partition.sh
}

# Define where the files will be installed
FILES:${PN} += "${sysconfdir}/keys/luks_key.bin.enc"
FILES:${PN} += "/usr/local/bin/mount_encrypted_partition.sh"

