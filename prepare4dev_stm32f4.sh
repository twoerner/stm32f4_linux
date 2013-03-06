#!/bin/bash

# Run this script to prepare a development environment suitable for
# working with the stm32f4-discovery board.
#
# If you specify 'clean' on the cmdline, this script will clean up from
# a previous build and then exit. If you specify 'distclean', it will perform
# a clean as well as remove any files this script might download, and then
# exit.
#
# You can specify the cmdline option '--dont-free' to keep the script from
# removing things which are required to create the development environment,
# but which aren't expected to be of much use once it is setup.

THISSCRIPT=`basename $0`

BASEDIR=`pwd`
PREFIX_dir=$BASEDIR/local
PACKAGE_dir=$PREFIX_dir/packages

ENV_file="stm32f4.env"
unset CPATH CONFIG_SITE LD_LIBRARY_PATH PKG_CONFIG_PATH
DONTFREE=0

CTNG_stowdir=ctng-1.18.0

REQUIREDTOOLS=(\
	wget \
	sha256sum \
	unzip \
	gzip \
	bzip2 \
	git \
	wc \
	basename \
	)

REQUIREDTHINGS=(\
	config/ctng-1.18.0--stm32f4.config \
	)

THINGSTOGET=(\
	stow-1.3.3.tar.gz \
	crosstool-ng-1.18.0.tar.bz2 \
	stsw-stm32068.zip \
	stlink-bbecbc1e81.tar.gz \
	)
THINGSTOGET_from=(\
	http://ftp.gnu.org/gnu/stow \
	http://crosstool-ng.org/download/crosstool-ng \
	http://www.st.com/st-web-ui/static/active/en/st_prod_software_internet/resource/technical/software/firmware \
	https://api.github.com/repos/texane/stlink/tarball/bbecbc1e81 \
	)
THINGSTOGET_sha256=(\
	0cdc7fb7861e83785edd2de127268f8a72ed9ae524ddc4beca236cfd63d1f8b0 \
	6961812e8cd9c28c8be32d9ac6dee36ed2645405dcbb70c0e9646672febd2be6 \
	8e67f7b930c6c02bd7f89a266c8d1cae3b530510b7979fbfc0ee0d57e7f88b81 \
	bcd5119fc3fee27881975f4077ef9cf5850607d3b3cea3962c2500949ba7888f \
	)

usage() {
	echo "usage: `basename $0` [OPTIONS] [<cmd>]"
	echo "  where:"
	echo "    [OPTIONS] can be:"
	echo "      --help | -h            print this help and exit successfully"
	echo "      --dont-free            don't cleanup build disk space as build proceeds"
	echo "    <cmd> is one of:"
	echo "      clean                  just cleanup and exit"
	echo "      distclean              cleanup, and remove downloaded files"
}

exit_cleanup() {
	local _dircnt=`dirs -p | wc -l`
	local _i

	if [ $_dircnt -gt 1 ]; then
		_dircnt=`expr $_dircnt - 1`
		for ((_i=0; _i<$_dircnt; ++_i)); do
			popd
		done
	fi

	if [ $DONTFREE -ne 1 ]; then
		# remove ctng
		pushd $PACKAGE_dir
			stow -D $CTNG_stowdir
			rm -fr $CTNG_stowdir
		popd

		# remove stow
		pushd local/src/stow-1.3.3
			make uninstall
		popd

		chmod -R 777 local/man local/info local/src
		rm -fr local/man local/info local/src local/build
	fi
}

remove_downloads() {
	if [ -d Downloads ]; then
		pushd Downloads
			for DLFILE in $THINGSTOGET; do
				rm -f $DLFILE
			done
		popd
	fi
}

# check cmdline args
CMDLINE=`getopt -o h -l dont-free,help -n $0 -- "$@"`
if [ $? -ne 0 ]; then
	echo "getopt(1) invocation error"
	exit 1
fi
eval set -- "$CMDLINE"
while [ 1 ]; do
	case "$1" in
		--dont-free)
			DONTFREE=1
			;;
		--help|-h)
			usage
			exit 0
			;;
		--)
			shift
			break
			;;
		*)
			echo "yoddle"
			;;
	esac
	shift
done

if [ $# -gt 1 ]; then
	echo "invalid cmdline arg count"
	usage
	exit 1
fi

# clean up
if [ -d local ]; then
	chmod -R 777 local
	rm -fr local
fi
rm -f $ENV_file

# "main"
# does the user want to cleanup?
if [ x"$1" = x"clean" ]; then
	exit 0
fi
if [ x"$1" = x"distclean" ]; then
	remove_downloads
	exit 0
fi

# make sure the tools we need are available
for ((i=0; i<${#REQUIREDTOOLS[*]}; ++i)); do
	which ${REQUIREDTOOLS[$i]} > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "required tool '${REQUIREDTOOLS[$i]}' not found"
		exit 1
	fi
done

# make sure the things we need are available
for ((i=0; i<${#REQUIREDTHINGS[*]}; ++i)); do
	if [ ! -r ${REQUIREDTHINGS[$i]} ]; then
		echo "required thing '${REQUIREDTHINGS[$i]}' not found"
		exit 1
	fi
done

trap exit_cleanup EXIT

# get tarballs etc
mkdir -p Downloads || exit 1
DL_dir=$BASEDIR/Downloads
pushd Downloads
	for ((i=0; i<${#THINGSTOGET[*]}; ++i)); do
		if [ ! -f ${THINGSTOGET[$i]} ]; then
			# it is amazing github offers this, but it has to be handled differently
			if [ $i -eq 3 ]; then
				wget -O ${THINGSTOGET[$i]} --no-check-certificate ${THINGSTOGET_from[$i]}
			else
				wget ${THINGSTOGET_from[$i]}/${THINGSTOGET[$i]}
			fi
		fi
		echo "${THINGSTOGET_sha256[$i]} ${THINGSTOGET[$i]}" > CHK
		sha256sum -c CHK
		if [ $? -ne 0 ]; then
			echo "sha256 hash of ${THINGSTOGET[$i]} is invalid, please delete so it can be re-downloaded"
			rm -f CHK
			exit 1
		fi
		rm -f CHK
	done
popd

# build
mkdir -p local/src || exit 1
export PATH=$PREFIX_dir/bin:$PATH

# stow
pushd local/src
	gzip -d < $DL_dir/stow-1.3.3.tar.gz | tar xf - || exit 1
	pushd stow-1.3.3
		./configure --prefix=$PREFIX_dir || exit 1
		make install || exit 1
	popd
popd

# st-link
STLINK_stowdir="stlink-bbecbc1e81"
if [ -d $PACKAGE_dir/$STLINK_stowdir ]; then
	pushd $PACKAGE_dir
		stow -D $STLINK_stowdir
		rm -fr $STLINK_stowdir
	popd
fi
pushd local/src
	gzip -d < $DL_dir/stlink-bbecbc1e81.tar.gz | tar xf - || exit 1
	pushd texane-stlink-bbecbc1
		./autogen.sh || exit 1
		./configure --prefix=$PACKAGE_dir/$STLINK_stowdir || exit 1
		make install || exit 1
	popd
popd
pushd $PACKAGE_dir
	stow $STLINK_stowdir || exit 1
popd

# crosstool-ng
if [ -d $PACKAGE_dir/$CTNG_stowdir ]; then
	pushd $PACKAGE_dir
		stow -D $CTNG_stowdir
		rm -fr $CTNG_stowdir
	popd
fi
pushd local/src
	bzip2 -d < $DL_dir/crosstool-ng-1.18.0.tar.bz2 | tar xf - || exit 1
	patch -p0 < $BASEDIR/config/ctng-newlib.diff || exit 1
	cd crosstool-ng-1.18.0
	./configure --prefix=$PACKAGE_dir/$CTNG_stowdir || exit 1
	make install || exit 1
popd
pushd $PACKAGE_dir
	stow $CTNG_stowdir || exit 1
popd

# cross-compiler
CROSSARM_stowdir="arm-stm32f4-eabi"
if [ -d $PACKAGE_dir/$CROSSARM_stowdir ]; then
	pushd $PACKAGE_dir
		stow -D $CROSSARM_stowdir
		rm -fr $CROSSARM_stowdir
	popd
fi
mkdir -p local/src/$CROSSARM_stowdir || exit 1
pushd local/src/$CROSSARM_stowdir
	ct-ng arm-unknown-eabi || exit 1
	cp $BASEDIR/config/ctng-1.18.0--stm32f4.config .config || exit 1
	sed -i -e "s#^CT_LOCAL_TARBALLS_DIR#CT_LOCAL_TARBALLS_DIR=\"$DL_dir\"#" .config || exit 1
	sed -i -e "s#^CT_PREFIX_DIR#CT_PREFIX_DIR=\"$PACKAGE_dir/$CROSSARM_stowdir\"#" .config || exit 1
	ct-ng build || exit 1
popd
pushd $PACKAGE_dir
	stow $CROSSARM_stowdir || exit 1
popd

# ST code
mkdir -p local/src/st || exit 1
pushd local/src/st
	unzip $DL_dir/stsw-stm32068.zip
	chmod -R +w STM32F4-Discovery_FW_V1.1.0
	pushd STM32F4-Discovery_FW_V1.1.0
		patch -p1 < $BASEDIR/config/stcode.diff || exit 1
		CROSS=arm-stm32f4-eabi- PREFIX=$PACKAGE_dir/st make install-headers || exit 1
		CROSS=arm-stm32f4-eabi- PREFIX=$PACKAGE_dir/st make install || exit 1
	popd
popd
pushd $PACKAGE_dir/st
	stow -t ../../arm-stm32f4-eabi/sysroot/lib lib || exit 1
	stow -t ../../include include || exit 1
popd

# create environment file
rm -f $ENV_file
echo "export CPATH=$PREFIX_dir/include" > $ENV_file
echo "export PATH=$PREFIX_dir/bin:\$PATH" >> $ENV_file
echo 'export PS1="${PS1}stm32f4> "' >> $ENV_file
