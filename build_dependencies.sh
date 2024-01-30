#!/bin/sh

PROJECT_ROOT=$(pwd)

# IM4 xcode project file
IM4PROJ=IM4.xcodeproj

# dependency directory
DEPDIR=dep

# dependency downloads
DL_OPENSSL=https://www.openssl.org/source/openssl-3.2.1.tar.gz
DL_LIBSTROPHE=https://github.com/strophe/libstrophe/releases/download/0.12.3/libstrophe-0.12.3.tar.bz2
DL_LIBGPGERR=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-1.47.tar.bz2
DL_LIBGCRYPT=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-1.10.3.tar.bz2
DL_LIBOTR=https://otr.cypherpunks.ca/libotr-4.1.1.tar.gz

SHA256_OPENSSL="83c7329fe52c850677d75e5d0b0ca245309b97e8ecbcfdc1dfdc4ab9fac35b39  openssl-3.2.1.tar.gz"
SHA256_LIBSTROPHE="1a978b244ca6bacfec60f2a916ac3ce7c564fa1723a6d2a89e458ad457c6574f  libstrophe-0.12.3.tar.bz2"
SHA256_LIBGPGERR="9e3c670966b96ecc746c28c2c419541e3bcb787d1a73930f5e5f5e1bcbbb9bdb  libgpg-error-1.47.tar.bz2"
SHA256_LIBGCRYPT="8b0870897ac5ac67ded568dcfadf45969cfa8a6beb0fd60af2a9eadc2a3272aa  libgcrypt-1.10.3.tar.bz2"
SHA256_LIBOTR="8b3b182424251067a952fb4e6c7b95a21e644fbb27fbd5f8af2b2ed87ca419f5  libotr-4.1.1.tar.gz"


DIR_OPENSSL=openssl-3.2.1
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


for url in $DL_OPENSSL $DL_LIBSTROPHE $DL_LIBGPGERR $DL_LIBGCRYPT $DL_LIBOTR; do
	# clear previous downloads
	rm -Rf $(basename $url)

	echo "download: $url"
	if ! curl -L -O $url; then
		echo "download failed"
		exit 1
	fi

	tar xvfz $(basename $url)
done

# check download hashes
DL_OPENSSL_SHA256=$(shasum -a 256 openssl-3.2.1.tar.gz)
DL_LIBSTROPHE_SHA256=$(shasum -a 256 libstrophe-0.12.3.tar.bz2)
DL_LIBGPGERR_SHA256=$(shasum -a 256 libgpg-error-1.47.tar.bz2)
DL_LIBGCRYPT_SHA256=$(shasum -a 256 libgcrypt-1.10.3.tar.bz2)
DL_LIBOTR_SHA256=$(shasum -a 256 libotr-4.1.1.tar.gz)

if [ "$SHA256_OPENSSL" != "$DL_OPENSSL_SHA256" ]; then
	echo "openssl: wrong checksum"
	echo "expected: $SHA256_OPENSSL"
	echo "download: $DL_OPENSSL_SHA256"
	exit 1
fi
if [ "$SHA256_LIBSTROPHE" != "$DL_LIBSTROPHE_SHA256" ]; then
	echo "libstrophe: wrong checksum"
	echo "expected: $SHA256_LIBSTROPHE"
	echo "download: $DL_LIBSTROPHE_SHA256"
	exit 1
fi
if [ "$SHA256_LIBGPGERR" != "$DL_LIBGPGERR_SHA256" ]; then
	echo "libgpg-err: wrong checksum"
	echo "expected: $SHA256_LIBGPGERR"
	echo "download: $DL_LIBGPGERR_SHA256"
	exit 1
fi
if [ "$SHA256_LIBGCRYPT" != "$DL_LIBGCRYPT_SHA256" ]; then
	echo "libgcrypt: wrong checksum"
	echo "expected: $SHA256_LIBGCRYPT"
	echo "download: $DL_LIBGCRYPT_SHA256"
	exit 1
fi
if [ "$SHA256_LIBOTR" != "$DL_LIBOTR_SHA256" ]; then
	echo "libotr: wrong checksum"
	echo "expected: $SHA256_LIBOTR"
	echo "download: $DL_LIBOTR_SHA256"
	exit 1
fi

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

install_name_tool -id @rpath/libcrypto.3.dylib $INSTALL_DIR/lib/libcrypto.3.dylib
install_name_tool -id @rpath/libssl.3.dylib $INSTALL_DIR/lib/libssl.3.dylib
install_name_tool -change $INSTALL_DIR/lib/libcrypto.3.dylib @rpath/libcrypto.3.dylib $INSTALL_DIR/lib/libssl.3.dylib


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

install_name_tool -id @rpath/libstrophe.0.dylib $INSTALL_DIR/lib/libstrophe.0.dylib


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
if [ -$? -ne 0 ]; then
	echo "libgpg-error make install failed"
	exit 2
fi
cd ..

install_name_tool -id @rpath/libgpg-error.0.dylib $INSTALL_DIR/lib/libgpg-error.0.dylib

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

install_name_tool -id @rpath/libgcrypt.20.dylib $INSTALL_DIR/lib/libgcrypt.20.dylib


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

install_name_tool -id @rpath/libotr.5.dylib $INSTALL_DIR/lib/libotr.5.dylib
