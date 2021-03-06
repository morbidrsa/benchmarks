#!/bin/sh

set -o nounset
set -o errexit

BENCHDIR="benches"
FILE="$(pwd)/test.dat"
BENCHES="		\
	dio-randread	\
	dio-randwrite	\
	dio-append"
OUT=""
SIZE="16G"
JOBS=$(getconf _NPROCESSORS_ONLN)

usage()
{
	echo "Usage: $(basename $0) [-f filename] [-o outdir]" >&2
	echo "" >&2
	echo "    -f filename      Output filename (default $FILE)" >&2
	echo "    -o outdir        Directory for results (default create)" >&2
}

while getopts "?hf:o:b:s:j:" arg; do
	case $arg in
		h)
			usage
			exit 0
			;;
		f)
			FILE=$OPTARG
			;;
		o)
			OUT=$OPTARG
			;;
		b)
			BENCHES=$OPTARG
			;;
		j)
			JOBS=$OPTARG
			;;
		s)
			SIZE=$OPTARG
			;;
	esac
done

if [ -z "$FILE" ]; then
	echo "Missing test file"
	exit 1
fi

if [ -z "$OUT" ]; then
	for i in $(seq -w 1 100); do
		OUT=/tmp/benchmark/$(date -I)-$i
		[ ! -e "$OUT" ] && break
	done
fi

mkdir -p $OUT
terse=$OUT/terse
full=$OUT/full

truncate --size 0 $terse
truncate --size 0 $full

if [ -b $FILE ]; then
	devname=$FILE
else
	devname=$(df $(dirname $FILE) | tail -1 | cut -d ' ' -f 1)
fi
vendor=$(sg_inq $devname | grep "Vendor identification:" | \
	cut -d ':' -f 2 | sed 's/ //')
model=$(sg_inq $devname | grep " Product identification:" | \
	cut -d ':' -f 2 | sed 's/ //')

for bench in $BENCHES; do
	out="$bench-$(echo $FILE | tr '/' '-' | tr ' ' '-')"
	echo "$bench:" | tee -a $terse
	$BENCHDIR/$bench -j $JOBS -s $SIZE $FILE > $out

	echo "**** Device $devname ($vendor $model) benchmark $bench:" >> $full
	cat $out >> $full
	echo >> $full

	sed -rne '/iops/ s/ +([[:alpha:]]+) ?:.*iops=([0-9]+).*/\1 \2/ p' $out | \
	awk '{printf("%8s %8d iops", $1, $2)} END {printf("\n")}' | \
	tee -a $terse

	rm $out
done
