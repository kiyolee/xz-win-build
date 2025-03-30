#!/bin/sh
# SPDX-License-Identifier: 0BSD

###############################################################################
#
# Author: Lasse Collin
#
###############################################################################

# Mandatory argument:
# $1 = test filename: compress_generated_<foo> or compress_prepared_<foo>
#
# Optional argument:
# $2 = directory of the xz and xzdec executables

if test $# -lt 1; then
  exit 77
fi

verbose=${verbose:-0}

# srcdir=$reporoot/tests
# bindir=$reporoot/build-VS*/{,x64/}{Release,Debug}

XZ_CMD=$bindir/xz.exe
XZDEC_CMD=$bindir/xzdec.exe
CREATE_COMPRESS_FILES_CMD=$bindir/create_compress_files.exe
CONFIG_H=`dirname $0`/../win32/config.h

# If xz wasn't built, this test is skipped.
if test ! -x $XZ_CMD; then
	echo "xz was not built, skipping this test."
	exit 77
fi

# xzdec isn't mandatory for this script.
test -x "$XZDEC_CMD" || XZDEC_CMD=

# If compression or decompression support is missing, this test is skipped.
# This isn't perfect as if only some compressors or decompressors are disabled
# then this script can still fail because for now this doesn't check the
# availability of each filter.
if test ! -f $CONFIG_H ; then
	:
elif grep 'define HAVE_ENCODERS' $CONFIG_H > /dev/null \
		&& grep 'define HAVE_DECODERS' $CONFIG_H > /dev/null ; then
	:
else
	echo "Compression or decompression support is disabled, skipping this test."
	exit 77
fi

# Find out if our shell supports functions.
eval 'unset foo ; foo() { return 42; } ; foo'
if test $? != 42 ; then
	echo "/bin/sh doesn't support functions, skipping this test."
	exit 77
fi

test_xz() {
	if $XZ -c "$@" "$FILE" > "$TMP_COMP"; then
    [ $verbose -gt 0 ] && echo "Compressing succeeded: $* $FILE"
		:
	else
		echo "Compressing failed: $* $FILE"
		exit 1
	fi

	if $XZ -cd "$TMP_COMP" > "$TMP_UNCOMP" ; then
    [ $verbose -gt 0 ] && echo "Decompressing succeeded: $* $FILE"
		:
	else
		echo "Decompressing failed: $* $FILE"
		exit 1
	fi

	if cmp "$TMP_UNCOMP" "$FILE" ; then
    [ $verbose -gt 0 ] && echo "Decompressed file matches the original: $* $FILE"
		:
	else
		echo "Decompressed file does not match the original: $* $FILE"
		exit 1
	fi

	if test -n "$XZDEC" ; then
		if $XZDEC "$TMP_COMP" > "$TMP_UNCOMP" ; then
      [ $verbose -gt 0 ] && echo "Decompressing succeeded: $* $FILE"
			:
		else
			echo "Decompressing failed: $* $FILE"
			exit 1
		fi

		if cmp "$TMP_UNCOMP" "$FILE" ; then
      [ $verbose -gt 0 ] && echo "Decompressed file matches the original: $* $FILE"
			:
		else
			echo "Decompressed file does not match the original: $* $FILE"
			exit 1
		fi
	fi
}

# Set memory usage limit for xz. xzdec has no memory usage limiter.
# Force single-threaded mode as the test files are small
# (so more than one thread wouldn't be used anyway) and
# the tests are usually run in parallel.
XZ="$XZ_CMD --memlimit-compress=48MiB --memlimit-decompress=5MiB \
		--no-adjust --threads=1"
XZDEC="$XZDEC_CMD"

# Create the required input file if needed.
#
# Derive temporary filenames for compressed and uncompressed outputs
# from the input filename. This is needed when multiple tests are
# run in parallel.
FILE=$1
TMP_COMP="tmp_comp_$FILE"
TMP_UNCOMP="tmp_uncomp_$FILE"

case $FILE in
	# compress_generated files will be created in the build directory
	# in the /tests/ sub-directory.
	compress_generated_*)
		if $CREATE_COMPRESS_FILES_CMD "$FILE" ; then
			:
		else
			rm -f "$FILE"
			echo "Failed to create the file '$FILE'."
			exit 1
		fi
		;;
	# compress_prepared files exist in the source directory since they
	# do not need to be copied or regenerated.
	compress_prepared_*)
		FILE="$srcdir/$FILE"
		;;
	'')
		echo "No test file was specified."
		exit 1
		;;
esac

# Remove temporary now (in case they are something weird), and on exit.
rm -f "$TMP_COMP" "$TMP_UNCOMP"
trap 'rm -f "$TMP_COMP" "$TMP_UNCOMP"' 0

# Compress and decompress the file with various filter configurations.
#
# Don't test with empty arguments; it breaks some ancient
# proprietary /bin/sh versions due to $@ used in test_xz().
test_xz -1
test_xz -2
test_xz -3
test_xz -4

test_filter()
{
	if test -f $CONFIG_H ; then
		grep "define HAVE_ENCODER_$1[ 1]*\$" $CONFIG_H > /dev/null || return
		grep "define HAVE_DECODER_$1[ 1]*\$" $CONFIG_H > /dev/null || return
	fi
	shift
	test_xz --filters="$* lzma2:dict=64KiB,nice=32,mode=fast"
}

test_filter DELTA delta:dist=1
test_filter DELTA delta:dist=4
test_filter DELTA delta:dist=256
test_filter X86 x86
test_filter POWERPC powerpc
test_filter IA64 ia64
test_filter ARM arm
test_filter ARMTHUMB armthumb
test_filter ARM64 arm64
test_filter SPARC sparc
test_filter RISCV riscv

exit 0
