SUMMARY = "Install disk encryption keys and configure disk encryption support"
DESCRIPTION = "This recipe installs encryption keys and a script for managing encrypted partitions."
LICENSE = "CLOSED"
AUTHOR = "Ammar Younas <muhammadammar.younas@arcelik.com>"
PR = "r0"

# Define the source URI for your key files and script

FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI += "file://encrypt.cfg"


# Add RDEPENDS for cryptodev modules
RDEPENDS:${PN} += "cryptodev-module cryptodev-tests"

# Specify the kernel configuration fragment to include
KERNEL_CONFIG_FRAGMENTS += "${WORKDIR}/encrypt.cfg"



