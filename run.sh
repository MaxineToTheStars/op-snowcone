# op-snowcone || run.sh
# --------------------------------
# OP Snow cone automation script.
#
# Authors: @MaxineToTheStars <https://github.com/MaxineToTheStars>
# ----------------------------------------------------------------

# Shebang
#!/usr/bin/env bash

# Configuration
declare -r CONFIG_BUILD_DEVICE_NAME="dre"
declare -r CONFIG_BUILD_LINEAGE_BRANCH_NAME="lineage-19.1"
declare -r CONFIG_SUBJECT_EMAIL_ADDRESS="android@android.com"
declare -r CONFIG_SUBJECT_ORGANIZATION="Android"

# Constants
declare -r CONST_LINEAGE_CICD_DOCKER_IMAGE="lineageos4microg/docker-lineage-cicd"
declare -r CONST_ROOT_DIRECTORY=$PWD

# Main
function main() {
    _build_download_dependencies
    _build_create_work_directories
    _build_generate_keys
    _build_run
}


# Creates the necessary work directories
function _build_create_work_directories() {
    # Validate we are in the root project directory
    cd $CONST_ROOT_DIRECTORY

    # Create the needed directories
    mkdir -p ./work/build-keys
    mkdir -p ./work/build-logs
    mkdir -p ./work/build-zips
    mkdir -p ./work/ccache
    mkdir -p ./work/custom-manifests
    mkdir -p ./work/lineage-src
}

# Downloads the needed dependencies
function _build_download_dependencies() {
    # Validate we are in the root project directory
    cd $CONST_ROOT_DIRECTORY

    # Update and Upgrade the system first
    sudo apt-get update && sudo apt-get upgrade

    # Again but now with --with-new-pkgs flag
    sudo apt-get update && sudo apt-get upgrade --with-new-pkgs

    # Install needed dependencies
    sudo apt-get install bash curl git nano openssl repo unzip

    # Pull docker image
    docker pull $CONST_LINEAGE_CICD_DOCKER_IMAGE
}

# Generates the needed keys for signing builds
function _build_generate_keys() {
    # Validate we are in the root project directory
    cd $CONST_ROOT_DIRECTORY

    # Declare and set the certificate subject
    subject="/C=US/ST=California/L=Mountain View/O=${CONFIG_SUBJECT_ORGANIZATION}/OU=${CONFIG_SUBJECT_ORGANIZATION}/CN=${CONFIG_SUBJECT_ORGANIZATION}/emailAddress=${CONFIG_SUBJECT_EMAIL_ADDRESS}"

    # Generate certificates
    for cert in bluetooth cyngn-app media networkstack platform releasekey sdk_sandbox shared testcert testkey verity; do \
        ./resources/make_key.sh $CONST_ROOT_DIRECTORY/work/build-keys/$cert "$subject"; \
    done

    # Generate APEX certificates
    for apex in com.android.adbd com.android.adservices com.android.adservices.api com.android.appsearch com.android.art com.android.bluetooth com.android.btservices com.android.cellbroadcast com.android.compos com.android.configinfrastructure com.android.connectivity.resources com.android.conscrypt com.android.devicelock com.android.extservices com.android.graphics.pdf com.android.hardware.biometrics.face.virtual com.android.hardware.biometrics.fingerprint.virtual com.android.hardware.boot com.android.hardware.cas com.android.hardware.wifi com.android.healthfitness com.android.hotspot2.osulogin com.android.i18n com.android.ipsec com.android.media com.android.media.swcodec com.android.mediaprovider com.android.nearby.halfsheet com.android.networkstack.tethering com.android.neuralnetworks com.android.ondevicepersonalization com.android.os.statsd com.android.permission com.android.resolv com.android.rkpd com.android.runtime com.android.safetycenter.resources com.android.scheduling com.android.sdkext com.android.support.apexer com.android.telephony com.android.telephonymodules com.android.tethering com.android.tzdata com.android.uwb com.android.uwb.resources com.android.virt com.android.vndk.current com.android.vndk.current.on_vendor com.android.wifi com.android.wifi.dialog com.android.wifi.resources com.google.pixel.camera.hal com.google.pixel.vibrator.hal com.qorvo.uwb; do \
        subject="/C=US/ST=California/L=Mountain View/O=${CONFIG_SUBJECT_ORGANIZATION}/OU=${CONFIG_SUBJECT_ORGANIZATION}/CN=${apex}/emailAddress=${CONFIG_SUBJECT_EMAIL_ADDRESS}"; \
        ./resources/make_key_modified.sh $CONST_ROOT_DIRECTORY/work/build-keys/$apex "$subject"; \
        openssl pkcs8 -in $CONST_ROOT_DIRECTORY/work/build-keys/$apex.pk8 -inform DER -nocrypt -out $CONST_ROOT_DIRECTORY/work/build-keys/$apex.pem; \
    done
}

# Runs the build system
function _build_run() {
    # Validate we are in the root project directory
    cd $CONST_ROOT_DIRECTORY

    # Copy the XML file to the work directory
    cp --recursive --update --verbose ./resources/dre.xml ./work/custom-manifests/dre.xml
    cp --recursive --update --verbose ./resources/microg.xml ./work/custom-manifests/microg.xml

    # Run
    docker run \
    -e "BRANCH_NAME=${CONFIG_BUILD_LINEAGE_BRANCH_NAME}" \
    -e "BUILD_TYPE=userdebug" \
    -e "DEVICE_LIST=${CONFIG_BUILD_DEVICE_NAME}" \
    -e "INCLUDE_PROPRIETARY=false" \
    -e "RELEASE_TYPE=OP-SNOWCONE" \
    -e "SIGN_BUILDS=true" \
    -e "WITH_GMS=true" \
    -e "ZIP_UP_IMAGES=true" \
    -v "${CONST_ROOT_DIRECTORY}/work/build-keys:/srv/keys" \
    -v "${CONST_ROOT_DIRECTORY}/work/build-logs:/srv/logs" \
    -v "${CONST_ROOT_DIRECTORY}/work/build-zips:/srv/zips" \
    -v "${CONST_ROOT_DIRECTORY}/work/ccache:/srv/ccache" \
    -v "${CONST_ROOT_DIRECTORY}/work/custom-manifests:/srv/local_manifests" \
    -v "${CONST_ROOT_DIRECTORY}/work/lineage-src:/srv/src" \
    --memory 16g \
    --memory-swap 115g \
    lineageos4microg/docker-lineage-cicd
}

# Execute
main
