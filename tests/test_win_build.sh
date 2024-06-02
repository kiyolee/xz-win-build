#!/bin/sh

srcdir=`dirname $0`
bindir=${bindir:-../build-VS2022/x64/Release}
verbose=${verbose:-0}

cd "$srcdir"

trap 'rm -f compress_generated_abc compress_generated_random compress_generated_text' 0

for i in \
    compress_generated_abc \
    compress_generated_random \
    compress_generated_text \
    ; do
  if bindir="$bindir" srcdir="$srcdir" verbose="$verbose" ./test_compress_win_build.sh $i; then
    echo "SUCCEED: test_compress $i"
  else
    echo "FAILED: test_compress $i"
    exit 1
  fi
done

rm -f compress_generated_abc compress_generated_random compress_generated_text
trap '' 0

if bindir="$bindir" srcdir="$srcdir" verbose="$verbose" ./test_files_win_build.sh; then
  echo "SUCCEED: test_files"
else
  echo "FAILED: test_files"
  exit 1
fi

for i in "$bindir"/test*.exe; do
  if $i; then
    echo "SUCCEED: $i"
  else
    echo "FAILED: $i"
    exit 1
  fi
done
