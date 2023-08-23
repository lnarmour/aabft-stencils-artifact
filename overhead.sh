#!/bin/bash

SCRIPT_DIR=`dirname -- $0`

function generate {
    name=$1
    H=$2
    L=$3
    force=$4
    if [[ ! -d $SCRIPT_DIR/$name/$H.$L || -n $force ]]; then
        $SCRIPT_DIR/generate.sh $SCRIPT_DIR/inputs/$name.alpha $name $H $L
    fi
}

function compile {
    name=$1
    H=$2
    L=$3
    force=$4
    for version in 'abft' 'noabft'
    do
        if [[ ! -f $SCRIPT_DIR/$name/$H.$L/codegen/$version/$name || -n $force ]]; then
            make -C $SCRIPT_DIR/$name/$H.$L/codegen/$version
        fi
    done
}

function evaluate {
    name=$1
    H=$2
    L=$3
    T=$4
    N=$5
    num_runs=$6
    for version in 'abft' 'noabft'
    do
        if [[ -n $VERSION && $version != $VERSION ]]; then
            continue
        fi
        program=$SCRIPT_DIR/$name/$H.$L/codegen/$version/$name
        for run in $(seq 1 $num_runs)
        do
            exec_time=`$program $T $N | cut -d' ' -f4`
            if [[ $VERSION == 'noabft' ]]; then
                echo "$name,-,-,$version,$exec_time"
            else
                echo "$name,$H,$L,$T,$N,$version,$exec_time"
            fi
        done
    done
}

function do_single {
    name=$1
    H=$2
    L=$3
    T=$4
    N=$5
    num_runs=$6
    force=$7

    if [[ -z $name || -z $H || -z $L || -z $T || -z $N ]]; then
        echo "usage: name H L T N [num_runs [force]]"
        return 1
    fi   

    if [[ -z $num_runs ]]; then
        num_runs=3
    fi
 
    generate $name $H $L $force 1>&2
    compile $name $H $L $force 1>&2
    if [[ -z $LOG_FILE ]]; then
        evaluate $name $H $L $T $N $num_runs
    else
        evaluate $name $H $L $T $N $num_runs >> $LOG_FILE
    fi
}

NUM_RUNS=3

function usage {
    echo "usage: $0 [-h] [-f] [-s] [-r R] [name H L T N]";
    echo "options:"
    echo "    -h, --help           :  Display this menu";
    echo "    -f, --force          :  Force regeneration and recompilation"
    echo "    -s, --do-single      :  Only run a single instance"
    echo "    -r, --num-runs       :  Run each instance R times (default: $NUM_RUNS)"
    echo "parameters:"
    echo "     name :  stencil name"
    echo "     H    :  Hyper-trapezoidal height of checksum regions (across time)"
    echo "     L    :  Hyper-trapezoidal ceiling side length of checksum regions (across space)"
    echo "     T    :  Number of time steps to run stencil iteration"
    echo "     N    :  Size of stencil data space dimensions"
    echo ""
    echo "Parameters are only required if running a single instance"
    echo ""
}

# parse args
PARAMS=""
while (( "$#" )); do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -f|--force)
            FORCE=1
            shift 1
            ;;
        -s|--do-single)
            DO_SINGLE=1
            shift 1
            ;;
        -r|--num-runs)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                NUM_RUNS=$2
                shift 2
            else
                echo "argument missing for -- $1"
                exit 1
            fi
            ;;
        -*|--*=) # unsupported flags
            echo "unrecognized option -- $(echo $1 | sed 's~^-*~~')" >&2
            usage;
            exit 1
            ;;
        *) # preserve positional arguments
            PARAMS="$PARAMS $1"
            shift
            ;;
    esac
done

eval set -- "$PARAMS";


if [[ -n $DO_SINGLE ]]; then
    name=$1
    H=$2
    L=$3
    T=$4
    N=$5
    do_single $name $H $L $T $N $NUM_RUNS $FORCE
    
    exit 0
fi




if [[ -n $LOG_FILE ]]; then
    date > $LOG_FILE
fi

T1d=100
N1d=1000000000
for name in 'star1d1r' 'star1d2r'
do
    # all noabft versions are identical
    VERSION='noabft' do_single $name 2 10 $T1d $N1d $@
    for L in 50 100 150 200;
    do
        for H in 4 8 12 16;
        do
            VERSION='abft' do_single $name $H $L $T1d $N1d $@
        done
    done
done

T2d=100
N2d=30000
for name in 'star2d1r' 'star2d2r'
do
    # all noabft versions are identical
    VERSION='noabft' do_single $name 2 10 $T2d $N2d $@
    for L in 40 80 120;
    do
      for H in 4 8 12 16;
        do
            VERSION='abft' do_single $name $H $L $T2d $N2d $@
        done
    done
done

T3d=100
N3d=1000
for name in 'star3d1r' 'star3d2r'
do
    # all noabft versions are identical
    VERSION='noabft' do_single $name 2 10 $T3d $N3d $@
    for L in 40 80 120;
    do
        for H in 4 8 12 16;
        do
            VERSION='abft' do_single $name $H $L $T3d $N3d $@
        done
    done
done

if [[ -n $LOG_FILE ]]; then
    date >> $LOG_FILE
fi
