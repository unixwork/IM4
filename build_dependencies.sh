#!/bin/sh

PROJECT_ROOT=$(pwd)

# IM4 xcode project file
IM4PROJ=IM4.xcodeproj

# dependency directory
DEPDIR=dep

# dependency downloads
DL_OPENSSL=https://www.openssl.org/source/openssl-3.2.0.tar.gz
DL_LIBSTROPHE=https://github.com/strophe/libstrophe/releases/download/0.12.3/libstrophe-0.12.3.tar.bz2
DL_LIBGPGERR=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.47.tar.bz2
DL_LIBCRYPT=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.10.3.tar.bz2
DL_LIBOTR=https://otr.cypherpunks.ca/libotr-4.1.1.tar.gz

DIR_OPENSSL=openssl-3.2.0
DIR_LIBSTROPHE=libstrophe-0.12.3
DIR_LIBGPGERR=libgpg-error-1.47
DIR_LIBGCRYPT=libgcrypt-1.10.3
DIR_LIBOTR=libotr-4.1.1


# check current directory
if [ ! -d "$IM4PROJ" ]; then
	echo "Xcode project $IM4PROJ not found. Abort."
	exit 1
fi


# download dependencies
mkdir -p $DEPDIR
cd $DEPDIR


#for url in $DL_OPENSSL $DL_LIBSTROPHE $DL_LIBGPGERR $DL_LIBCRYPT $DL_LIBOTR; do
#	# clear previous downloads
#	rm -Rf $(basename $url)
#
#	echo "download: $url"
#	if ! curl -L -O $url; then
#		echo "download failed"
#		exit 1
#	fi
#
#	tar xvfz $(basename $url)
#done

# build openssl
cd $DIR_OPENSSL

INSTALL_DIR="$PROJECT_ROOT/$DEPDIR/install"

./Configure --prefix=$INSTALL_DIR
if [ $? -ne 0 ]; then
	echo "openssl configure failed"
	exit 2
fi
make
if [ $? -ne 0 ]; then
	echo "openssl make failed"
	exit 2
fi
make install
if [ $? -ne 0 ]; then
	echo "openssl make install failed"
	exit 2
fi
cd ..


# build libstrophe
export CFLAGS=-I$INSTALL_DIR/include
export LDFLAGS=-L$INSTALL_DIR/lib
export PATH=$PATH:$INSTALL_DIR/bin

cd $DIR_LIBSTROPHE

./configure --prefix=$INSTALL_DIR
if [ -$? -ne 0 ]; then
	echo "libstrophe configure failed"
	exit 2
fi
make
if [ -$? -ne 0 ]; then
	echo "libstrophe make failed"
	exit 2
fi
make install
if [ -$? -ne 0]; then
	echo "libstrophe make install failed"
	exit 2
fi
cd ..


# build libgpg-error
cd $DIR_LIBGPGERR

./configure --prefix=$INSTALL_DIR
if [ -$? -ne 0 ]; then
	echo "libgpg-error configure failed"
	exit 2
fi
make
if [ $? -ne 0 ]; then
	echo "libgpg-error make failed"
	exit 2
fi
make install
if [ -$? -ne 0]; then
	echo "libgpg-error make install failed"
	exit 2
fi
cd ..


# build libgcrypt
cd $DIR_LIBGCRYPT

./configure --prefix=$INSTALL_DIR
if [ -$? -ne 0 ]; then
	echo "libgcrypt configure failed"
	exit 2
fi
make
if [ $? -ne 0 ]; then
	echo "libgcrypt make failed"
	exit 2
fi
make install
if [ -$? -ne 0]; then
	echo "libgcrypt make install failed"
	exit 2
fi
cd ..


# build libotr
cd $DIR_LIBOTR

./configure --prefix=$INSTALL_DIR
if [ -$? -ne 0 ]; then
	echo "libotr configure failed"
	exit 2
fi
make
if [ $? -ne 0 ]; then
	echo "libotr make failed"
	exit 2
fi
make install
if [ -$? -ne 0 ]; then
	echo "libotr make install failed"
	exit 2
fi
cd ..