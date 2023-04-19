#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

usage() { 
	echo "======================================================================================"
	echo "Usage: $0"
	echo "======================================================================================"
	echo " -g [REQUIRED] 	The resource id of the target compute gallery"
	echo " -i [OPTIONAL] 	The name of the image to build"
	echo " -p [OPTIONAL] 	The name of the publisher of the image"
	echo " -o [OPTIONAL] 	The name of the offer of the image"
	echo " -s [OPTIONAL] 	The name of the SKU of the image"
	echo " -d [FLAG] 		Enable debug mode for Packer"
	exit 1; 
}

displayHeader() {
	echo -e "\n======================================================================================"
	echo $1
	echo -e "======================================================================================\n"
}

while getopts 'g:i:p:o:s:rd' OPT; do
    case "$OPT" in
		g)
			GALLERYID="${OPTARG}" ;;
		i)
			IMAGE="${OPTARG}" ;;
		p)
			PUBLISHER="${OPTARG}" ;;
		o)
			OFFER="${OPTARG}" ;;
		s)
			SKU="${OPTARG}" ;;
		d)  
			PACKER_LOG='on' ;;
		*) 
			usage ;;
    esac
done

clear

buildImage() {

	IMAGENAME=$(basename "$(dirname "$1")")
	IMAGEOFFER=$(cat $1 | grep 'image_offer' | cut -d '"' -f2)
	IMAGESKU=$(cat $1 | grep 'image_sku' | cut -d '"' -f2)
	IMAGEOSTYPE=$(cat $1 | grep 'os_type' | cut -d '"' -f2)
	IMAGEVERSION=$(date +%Y.%m%d.%H%M)

	GALLERYJSON=$(az resource show --ids $GALLERYID)
	GALLERYNAME=$(echo $GALLERYJSON | jq -r .name)
	GALLERYRESOURCEGROUP=$(echo $GALLERYJSON | jq -r .resourceGroup)
	GALLERYRELOCATION=$(echo $GALLERYJSON | jq -r .location)
	GALLERYSUBSCRIPTION=$(echo $GALLERYID | cut -d / -f3)

	if [ -z "$PUBLISHER" ]; then
		PUBLISHER="$GALLERYNAME"
	fi

	if [ ! -z "$OFFER" ]; then
		IMAGEOFFER="$OFFER"
	fi

	if [ ! -z "$SKU" ]; then
		IMAGESKU="$SKU"
	fi

	pushd "$(dirname "$1")" > /dev/null

	displayHeader "Ensure image definition $1" | tee ./build.pkr.log

	az sig image-definition create \
		--resource-group $GALLERYRESOURCEGROUP \
		--gallery-name $GALLERYNAME \
		--gallery-image-definition $IMAGENAME \
		--publisher $PUBLISHER \
		--offer $IMAGEOFFER \
		--sku $IMAGESKU \
		--os-type $IMAGEOSTYPE \
		--os-state Generalized \
		--hyper-v-generation V2 \
		--features 'SecurityType=TrustedLaunch' \
		--only-show-errors | tee -a ./build.pkr.log

	displayHeader "Init image $1" | tee -a ./build.pkr.log

	packer init \
		. 2>&1 | tee -a ./build.pkr.log

	displayHeader "Building image $1" | tee -a ./build.pkr.log

	packer build \
		-force \
		-color=false \
		-var "galleryName=$GALLERYNAME" \
		-var "galleryResourceGroup=$GALLERYRESOURCEGROUP" \
		-var "gallerySubscription=$GALLERYSUBSCRIPTION" \
		-var "galleryLocation=$GALLERYRELOCATION" \
		-var "imageName=$IMAGENAME" \
		-var "imageVersion=$IMAGEVERSION" \
		. 2>&1 | tee -a ./build.pkr.log

	popd > /dev/null
}

while read IMAGEPATH; do

	if [[ -z "$IMAGE" || "$(echo "$IMAGE" | tr '[:upper:]' '[:lower:]')" == "$(echo "$(basename $(dirname $IMAGEPATH))" | tr '[:upper:]' '[:lower:]')" ]]; then

		# enforce our global set of variables on the image to build
		cp -f ./variables.pkr.hcl $(dirname $IMAGEPATH)/variables.pkr.hcl

		# start the build process
		buildImage $IMAGEPATH

	fi

	# do some clean up work
	rm -rf $(dirname $IMAGEPATH)/variables.pkr.hcl

done < <(find . -type f -path './*/build.pkr.hcl')