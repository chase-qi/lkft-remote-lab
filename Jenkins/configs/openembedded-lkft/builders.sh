#!/bin/bash

set -e

# workaround EDK2 is confused by the long path used during the build
# and truncate files name expected by VfrCompile
sudo mkdir -p /srv/oe
sudo chown buildslave:buildslave /srv/oe
cd /srv/oe

trap cleanup_exit INT TERM EXIT

cleanup_exit()
{
    echo "Running cleanup_exit..."
}

if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update; then
  echo "INFO: apt update error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 update || true
fi
pkg_list="virtualenv python-pip android-tools-fsutils chrpath cpio diffstat gawk libmagickwand-dev libmath-prime-util-perl libsdl1.2-dev libssl-dev python-requests texinfo vim-tiny whiptail libelf-dev"
if ! sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}; then
  echo "INFO: apt install error - try again in a moment"
  sleep 15
  sudo DEBIAN_FRONTEND=noninteractive apt-get -q=2 install -y ${pkg_list}
fi

# Install jinja2-cli and ruamel.yaml
pip install --user --force-reinstall jinja2-cli ruamel.yaml

set -ex

mkdir -p ${HOME}/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ${HOME}/bin/repo
chmod a+x ${HOME}/bin/repo
export PATH=${HOME}/bin:${PATH}

# initialize repo if not done already
if [ ! -e ".repo/manifest.xml" ]; then
   repo init -u https://github.com/96boards/oe-rpb-manifest.git -b ${MANIFEST_BRANCH}

   # link to shared downloads on persistent disk
   # our builds config is expecting downloads and sstate-cache, here.
   # DL_DIR = "${OEROOT}/sources/downloads"
   # SSTATE_DIR = "${OEROOT}/build/sstate-cache"
   mkdir -p ${HOME}/srv/oe/downloads ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH}
   mkdir -p build
   ln -s ${HOME}/srv/oe/downloads
   ln -s ${HOME}/srv/oe/sstate-cache-${DISTRO}-${MANIFEST_BRANCH} sstate-cache
fi

repo sync
cp .repo/manifest.xml source-manifest.xml
repo manifest -r -o pinned-manifest.xml
MANIFEST_COMMIT=$(cd .repo/manifests && git rev-parse --short HEAD)

# record changes since last build, if available
#BASE_URL=http://snapshots.linaro.org
#if wget -q ${BASE_URL}${PUB_DEST/\/${BUILD_NUMBER}\//\/latest\/}/pinned-manifest.xml -O pinned-manifest-latest.xml; then
#   repo diffmanifests ${PWD}/pinned-manifest-latest.xml ${PWD}/pinned-manifest.xml > manifest-changes.txt
#else
#    echo "latest build published does not have pinned-manifest.xml, skipping diff report"
#fi

# the setup-environment will create auto.conf and site.conf
# make sure we get rid of old config.
# let's remove the previous TMPDIR as well.
# we want to preserve build/buildhistory though.
rm -rf conf build/conf build/tmp-*glibc/

# Accept EULA if/when needed
export EULA_dragonboard410c=1
export EULA_stih410b2260=1
source setup-environment build

# Add job BUILD_NUMBER to output files names
cat << EOF >> conf/auto.conf
IMAGE_NAME_append = "-${BUILD_NUMBER}"
KERNEL_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
MODULE_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
DT_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
BOOT_IMAGE_BASE_NAME_append = "-${BUILD_NUMBER}"
EOF

# get build stats to make sure that we use sstate properly
cat << EOF >> conf/auto.conf
INHERIT += "buildstats buildstats-summary"
EOF

# Set the kernel to use
distro_conf=$(find ../layers/meta-rpb/conf/distro -name rpb.inc)
cat << EOF >> ${distro_conf}
PREFERRED_PROVIDER_virtual/kernel = "${KERNEL_RECIPE}"
EOF

case "${KERNEL_RECIPE}" in
  linux-hikey-aosp|linux-generic-android-common-o*|linux-generic-lsk*|linux-generic-stable*)
    cat << EOF >> ${distro_conf}
PREFERRED_VERSION_${KERNEL_RECIPE} = "${KERNEL_VERSION}+git%"
EOF
    ;;
esac

# Use meta-oe version, required for mosh
cat << EOF >> ${distro_conf}
PREFERRED_VERSION_protobuf = "2.6.1+git%"
PREFERRED_VERSION_protobuf-native = "2.6.1+git%"
EOF

# Set the image types to use
cat << EOF >> ${distro_conf}
IMAGE_FSTYPES_remove = "ext4 iso wic"
EOF

case "${KERNEL_RECIPE}" in
  linux-*-aosp|linux-*-android-*)
    cat << EOF >> ${distro_conf}
CONSOLE = "ttyFIQ0"
EOF
    ;;
esac

cat << EOF >> ${distro_conf}
KERNEL_ALT_IMAGETYPE_remove_stih410-b2260 = "vmlinux"
EOF

# Mali GPU driver fails to build
# error: implicit declaration of function 'copy_from_user'
# [-Werror=implicit-function-declaration]
# Ignore the whole gpu MACHINE_FEATURES mechanism
stih410_b2260_conf=$(find ../layers/meta-st-cannes2/conf/machine -name stih410-b2260.conf)
sed -i -e '/gpu/d' ${stih410_b2260_conf}

# Include additional recipes in the image
[ "${MACHINE}" = "am57xx-evm" -o "${MACHINE}" = "stih410-b2260" ] || extra_pkgs="numactl"
cat << EOF >> conf/local.conf
CORE_IMAGE_BASE_INSTALL_append = " kernel-selftests kselftests-mainline kselftests-next libhugetlbfs-tests ltp ${extra_pkgs}"
CORE_IMAGE_BASE_INSTALL_append = " python python-misc python-modules python-numpy python-pexpect python-pyyaml"
CORE_IMAGE_BASE_INSTALL_append = " git mosh-server parted packagegroup-core-buildessential packagegroup-core-tools-debug tzdata"
EOF

# Override cmdline
cat << EOF >> conf/local.conf
CMDLINE_remove = "quiet"
EOF

# Remove recipes:
# - docker to reduce image size
cat << EOF >> conf/local.conf
RDEPENDS_packagegroup-rpb_remove = "docker"
EOF

cat << EOF >> conf/local.conf
DEFAULTTUNE_intel-core2-32 = "core2-64"
SERIAL_CONSOLES_remove_intel-core2-32 = "115200;ttyPCH0"
SERIAL_CONSOLES_append_dragonboard-410c = " 115200;ttyMSM1"
SERIAL_CONSOLES_append_hikey = " 115200;ttyAMA2"
EOF

# Enable lkft-metadata class
cat << EOF >> conf/local.conf
INHERIT += "lkft-metadata"
LKFTMETADATA_COMMIT = "1"
EOF

# Remove systemd firstboot and machine-id file
# Backport serialization change from v234 to avoid systemd tty race condition
mkdir -p ../layers/meta-96boards/recipes-core/systemd/systemd
wget -q http://people.linaro.org/~fathi.boudra/backport-v234-e266c06-v230.patch \
  -O ../layers/meta-96boards/recipes-core/systemd/systemd/backport-v234-e266c06-v230.patch
cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd/e2fsck.conf
[options]
# This will prevent e2fsck from stopping boot just because the clock is wrong
broken_system_clock = 1
EOF
cat << EOF >> ../layers/meta-96boards/recipes-core/systemd/systemd_%.bbappend
FILESEXTRAPATHS_prepend := "\${THISDIR}/\${PN}:"

SRC_URI += "\\
    file://backport-v234-e266c06-v230.patch \\
    file://e2fsck.conf \\
"

PACKAGECONFIG_remove = "firstboot"

do_install_append() {
    # Install /etc/e2fsck.conf to avoid boot stuck by wrong clock time
    install -m 644 -p -D \${WORKDIR}/e2fsck.conf \${D}\${sysconfdir}/e2fsck.conf

    rm -f \${D}\${sysconfdir}/machine-id
}

FILES_\${PN} += "\${sysconfdir}/e2fsck.conf "
EOF

# Update kernel recipe SRCREV
kernel_recipe=$(find ../layers/meta-96boards -name ${KERNEL_RECIPE}_${KERNEL_VERSION}.bb)
sed -i "s|^SRCREV_kernel = .*|SRCREV_kernel = \"${SRCREV_kernel}\"|" ${kernel_recipe}

# add useful debug info
cat conf/{site,auto}.conf
cat ${distro_conf}

# Temporary sstate cleanup to get lkft metadata generated
bitbake -c cleansstate kselftests-mainline kselftests-next ltp libhugetlbfs

time bitbake ${IMAGES}

DEPLOY_DIR_IMAGE=$(bitbake -e | grep "^DEPLOY_DIR_IMAGE="| cut -d'=' -f2 | tr -d '"')

# Prepare files to publish
rm -f ${DEPLOY_DIR_IMAGE}/*.txt
find ${DEPLOY_DIR_IMAGE} -type l -delete
mv /srv/oe/{source,pinned}-manifest.xml ${DEPLOY_DIR_IMAGE}
cat ${DEPLOY_DIR_IMAGE}/pinned-manifest.xml

# FIXME: IMAGE_FSTYPES_remove doesn't work
rm -f ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4 \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.iso \
      ${DEPLOY_DIR_IMAGE}/*.rootfs.wic \
      ${DEPLOY_DIR_IMAGE}/*.stimg

# FIXME: Sparse images here, until it gets done by OE
case "${MACHINE}" in
  juno|stih410-b2260|intel-core2-32)
    ;;
  *)
    for rootfs in ${DEPLOY_DIR_IMAGE}/*.rootfs.ext4.gz; do
      gunzip -k ${rootfs}
      sudo ext2simg -v ${rootfs%.gz} ${rootfs%.ext4.gz}.img
      rm -f ${rootfs%.gz}
      gzip -9 ${rootfs%.ext4.gz}.img
    done
    ;;
esac

# Create MD5SUMS file
find ${DEPLOY_DIR_IMAGE} -type f | xargs md5sum > MD5SUMS.txt
sed -i "s|${DEPLOY_DIR_IMAGE}/||" MD5SUMS.txt
mv MD5SUMS.txt ${DEPLOY_DIR_IMAGE}

# Build information
cat > ${DEPLOY_DIR_IMAGE}/HEADER.textile << EOF

h4. LKFT - OpenEmbedded

Build description:
* Build URL: "$BUILD_URL":$BUILD_URL
* Manifest URL: "https://github.com/96boards/oe-rpb-manifest.git":https://github.com/96boards/oe-rpb-manifest.git
* Manifest branch: ${MANIFEST_BRANCH}
* Manifest commit: "${MANIFEST_COMMIT}":https://github.com/96boards/oe-rpb-manifest/commit/${MANIFEST_COMMIT}
EOF

if [ -e "/srv/oe/manifest-changes.txt" ]; then
  # the space after pre.. tag is on purpose
  cat > ${DEPLOY_DIR_IMAGE}/README.textile << EOF

h4. Manifest changes

pre.. 
EOF
  cat /srv/oe/manifest-changes.txt >> ${DEPLOY_DIR_IMAGE}/README.textile
  mv /srv/oe/manifest-changes.txt ${DEPLOY_DIR_IMAGE}
fi

GCCVERSION=$(bitbake -e | grep "^GCCVERSION="| cut -d'=' -f2 | tr -d '"')
TARGET_SYS=$(bitbake -e | grep "^TARGET_SYS="| cut -d'=' -f2 | tr -d '"')
TUNE_FEATURES=$(bitbake -e | grep "^TUNE_FEATURES="| cut -d'=' -f2 | tr -d '"')
STAGING_KERNEL_DIR=$(bitbake -e | grep "^STAGING_KERNEL_DIR="| cut -d'=' -f2 | tr -d '"')

# lkft-metadata class generates metadata file, which can be sourced
for recipe in kselftests-mainline kselftests-next ltp libhugetlbfs; do
  source lkftmetadata/packages/*/${recipe}/metadata
done

BOOT_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "boot-*-${MACHINE}-*-${BUILD_NUMBER}*.img" | xargs -r basename)
ROOTFS_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.img.gz" | xargs -r basename)
ROOTFS_TARXZ_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "rpb-console-image-${MACHINE}-*-${BUILD_NUMBER}.rootfs.tar.xz" | xargs -r basename)
KERNEL_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*Image-*-${MACHINE}-*-${BUILD_NUMBER}.bin" | xargs -r basename)
case "${MACHINE}" in
  juno)
    DTB_IMG=$(find ${DEPLOY_DIR_IMAGE} -type f -name "*Image-*-${MACHINE}-r2-*-${BUILD_NUMBER}.dtb" | xargs -r basename)
    ;;
esac

# Local http file downloading server.
BASE_URL=http://192.168.11.205/snapshots
cat > ${DEPLOY_DIR_IMAGE}/build_config.json <<EOF
{
  "kernel_repo" : "${KERNEL_REPO}",
  "kernel_commit_id" : "${SRCREV_kernel}",
  "make_kernelversion" : "${MAKE_KERNELVERSION}",
  "kernel_branch" : "${KERNEL_BRANCH}",
  "kernel_describe" : "${KERNEL_DESCRIBE}",
  "kselftest_mainline_url" : "${KSELFTESTS_MAINLINE_URL}",
  "kselftest_mainline_version" : "${KSELFTESTS_MAINLINE_VERSION}",
  "kselftest_next_url" : "${KSELFTESTS_NEXT_URL}",
  "kselftest_next_version" : "${KSELFTESTS_NEXT_VERSION}",
  "ltp_url" : "${LTP_URL}",
  "ltp_version" : "${LTP_VERSION}",
  "ltp_revision" : "${LTP_REVISION}",
  "libhugetlbfs_url" : "${LIBHUGETLBFS_URL}",
  "libhugetlbfs_version" : "${LIBHUGETLBFS_VERSION}",
  "libhugetlbfs_revision" : "${LIBHUGETLBFS_REVISION}",
  "build_arch" : "${TUNE_FEATURES}",
  "compiler" : "${TARGET_SYS} ${GCCVERSION}",
  "build_location" : "${BASE_URL}/${PUB_DEST}"
}
EOF

cat << EOF > ${WORKSPACE}/post_build_lava_parameters
DEPLOY_DIR_IMAGE=${DEPLOY_DIR_IMAGE}
BASE_URL=${BASE_URL}
BOOT_URL=${BASE_URL}/${PUB_DEST}/${BOOT_IMG}
SYSTEM_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_IMG}
KERNEL_URL=${BASE_URL}/${PUB_DEST}/${KERNEL_IMG}
DTB_URL=${BASE_URL}/${PUB_DEST}/${DTB_IMG}
RECOVERY_IMAGE_URL=${BASE_URL}/${PUB_DEST}/juno-oe-uboot.zip
NFSROOTFS_URL=${BASE_URL}/${PUB_DEST}/${ROOTFS_TARXZ_IMG}
KERNEL_COMMIT=${SRCREV_kernel}
KERNEL_CONFIG_URL=${BASE_URL}/${PUB_DEST}/config
KERNEL_DEFCONFIG_URL=${BASE_URL}/${PUB_DEST}/defconfig
KSELFTESTS_MAINLINE_URL=${KSELFTESTS_MAINLINE_URL}
KSELFTESTS_MAINLINE_VERSION=${KSELFTESTS_MAINLINE_VERSION}
KSELFTESTS_NEXT_URL=${KSELFTESTS_NEXT_URL}
KSELFTESTS_NEXT_VERSION=${KSELFTESTS_NEXT_VERSION}
LTP_URL=${LTP_URL}
LTP_VERSION=${LTP_VERSION}
LTP_REVISION=${LTP_REVISION}
LIBHUGETLBFS_URL=${LIBHUGETLBFS_URL}
LIBHUGETLBFS_VERSION=${LIBHUGETLBFS_VERSION}
LIBHUGETLBFS_REVISION=${LIBHUGETLBFS_REVISION}
MAKE_KERNELVERSION=${MAKE_KERNELVERSION}
EOF
