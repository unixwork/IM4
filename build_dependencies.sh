#!/bin/sh

PROJECT_ROOT=$(pwd)

# IM4 xcode project file
IM4PROJ=IM4.xcodeproj

# dependency directory
DEPDIR=dep

# dependencies
OPENSSL_VERSION=3.4.0
LIBSTROPHE_VERSION=0.13.1
LIBGPGERR_VERSION=1.51
LIBGCRYPT_VERSION=1.11.0
LIBOTR_VERSION=4.1.1
ZLIB_VERSION=1.3.1
# dependency 
DL_OPENSSL=https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz
DL_ZLIB=http://zlib.net/zlib-$ZLIB_VERSION.tar.gz
DL_LIBSTROPHE=https://github.com/strophe/libstrophe/releases/download/$LIBSTROPHE_VERSION/libstrophe-$LIBSTROPHE_VERSION.tar.bz2
DL_LIBGPGERR=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-$LIBGPGERR_VERSION.tar.bz2
DL_LIBGCRYPT=https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-$LIBGCRYPT_VERSION.tar.bz2
DL_LIBOTR=https://otr.cypherpunks.ca/libotr-$LIBOTR_VERSION.tar.gz

SHA256_OPENSSL="e15dda82fe2fe8139dc2ac21a36d4ca01d5313c75f99f46c4e8a27709b7294bf  openssl-3.4.0.tar.gz"
SHA256_ZLIB="9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23  zlib-1.3.1.tar.gz"
SHA256_LIBSTROPHE="7768724d3d5f5f7b774fae4390be8d5ec00db71205e72477c3977bd90e1120cf  libstrophe-0.13.1.tar.bz2"
SHA256_LIBGPGERR="be0f1b2db6b93eed55369cdf79f19f72750c8c7c39fc20b577e724545427e6b2  libgpg-error-1.51.tar.bz2"
SHA256_LIBGCRYPT="09120c9867ce7f2081d6aaa1775386b98c2f2f246135761aae47d81f58685b9c  libgcrypt-1.11.0.tar.bz2"
SHA256_LIBOTR="8b3b182424251067a952fb4e6c7b95a21e644fbb27fbd5f8af2b2ed87ca419f5  libotr-4.1.1.tar.gz"


DIR_OPENSSL=openssl-$OPENSSL_VERSION
DIR_ZLIB=zlib-$ZLIB_VERSION
DIR_LIBSTROPHE=libstrophe-$LIBSTROPHE_VERSION
DIR_LIBGPGERR=libgpg-error-$LIBGPGERR_VERSION
DIR_LIBGCRYPT=libgcrypt-$LIBGCRYPT_VERSION
DIR_LIBOTR=libotr-$LIBOTR_VERSION


# check current directory
if [ ! -d "$IM4PROJ" ]; then
	echo "Xcode project $IM4PROJ not found. Abort."
	exit 1
fi


# download dependencies
mkdir -p $DEPDIR
cd $DEPDIR


for url in $DL_OPENSSL $DL_ZLIB $DL_LIBSTROPHE $DL_LIBGPGERR $DL_LIBGCRYPT $DL_LIBOTR; do
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
DL_OPENSSL_SHA256=$(shasum -a 256 openssl-$OPENSSL_VERSION.tar.gz)
DL_ZLIB_SHA256=$(shasum -a 256 zlib-$ZLIB_VERSION.tar.gz)
DL_LIBSTROPHE_SHA256=$(shasum -a 256 libstrophe-$LIBSTROPHE_VERSION.tar.bz2)
DL_LIBGPGERR_SHA256=$(shasum -a 256 libgpg-error-$LIBGPGERR_VERSION.tar.bz2)
DL_LIBGCRYPT_SHA256=$(shasum -a 256 libgcrypt-$LIBGCRYPT_VERSION.tar.bz2)
DL_LIBOTR_SHA256=$(shasum -a 256 libotr-$LIBOTR_VERSION.tar.gz)

if [ "$SHA256_OPENSSL" != "$DL_OPENSSL_SHA256" ]; then
	echo "openssl: wrong checksum"
	echo "expected: $SHA256_OPENSSL"
	echo "download: $DL_OPENSSL_SHA256"
	exit 1
fi
if [ "$SHA256_ZLIB" != "$DL_ZLIB_SHA256" ]; then
	echo "zlib: wrong checksum"
	echo "expected: $SHA256_ZLIB"
	echo "download: $DL_ZLIB_SHA256"
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



# build zlib
export CFLAGS=-I$INSTALL_DIR/include
export LDFLAGS=-L$INSTALL_DIR/lib
export PATH=$PATH:$INSTALL_DIR/bin
export zlib_CFLAGS=$CFLAGS
export zlib_LIBS="$LDFLAGS -lz"

cd $DIR_ZLIB

./configure --prefix=$INSTALL_DIR
if [ -$? -ne 0 ]; then
	echo "zlib configure failed"
	exit 2
fi
make
if [ -$? -ne 0 ]; then
	echo "zlib make failed"
	exit 2
fi
make install
if [ -$? -ne 0]; then
	echo "zlib make install failed"
	exit 2
fi
cd ..

install_name_tool -id @rpath/libz.$ZLIB_VERSION.dylib $INSTALL_DIR/lib/libz.$ZLIB_VERSION.dylib


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

# libgpg-error 1.50 build is broken
#patch < ../../libgpg-error.patch


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

cat >> install/bin/libgcrypt-config << __EOF__
#!/bin/sh

INSTALL_DIR=$INSTALL_DIR

if [ \$1 = "--version" ]; then
	echo "1.11.0"
	exit
fi

if [ \$1 = "--cflags" ]; then
	echo "-I\$INSTALL_DIR/include"
	exit
fi

if [ \$1 = "--libs" ]; then
	echo "-L\$INSTALL_DIR/lib -lgcrypt -lgpg-error"
	exit
fi
__EOF__

chmod +x install/bin/libgcrypt-config

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
