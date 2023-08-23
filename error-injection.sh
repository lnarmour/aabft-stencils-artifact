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
    program=$SCRIPT_DIR/$name/$H.$L/codegen/abft/$name.check
    for run in $(seq 1 $num_runs)
    do
        # An error is detected if more than 1 line is printed
        checksums_above_threshold=`$program $T $N | grep -v 'Execution time' | wc -l | sed 's~[ ][ ]*~~'`
        echo "$name,$H,$L,$T,$N,$BIT,$inj_site_loc,$THRESHOLD,$checksums_above_threshold"
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

function choose_random_inj_site {
    T=$1
    N=$2
    num_dims=$3
    ret="$((RANDOM % T))"
    for d in $(seq 1 $num_dims)
    do
        ret="$ret,$((RANDOM % N))"
    done
    echo $ret
}

function injection_site_header {
    inj_site_loc_header="t_inj"
    if [[ $NUM_DIMS -ge 1 ]]; then inj_site_loc_header="$inj_site_loc_header,i_inj"; fi
    if [[ $NUM_DIMS -ge 2 ]]; then inj_site_loc_header="$inj_site_loc_header,j_inj"; fi
    if [[ $NUM_DIMS -ge 3 ]]; then inj_site_loc_header="$inj_site_loc_header,k_inj"; fi
    echo $inj_site_loc_header
}

function export_injection_site {
    INJ=$1
    BIT=$2
    THRESHOLD=$3
    # export injection site env variable to be read by stencil check program
    export BIT=$BIT
    export THRESHOLD=$THRESHOLD
    export T_INJ=`echo $INJ | cut -d',' -f1`
    inj_site_loc="$T_INJ"
    if [[ $NUM_DIMS -ge 1 ]]; then 
        export I_INJ=`echo $INJ | cut -d',' -f2`
        inj_site_loc="$inj_site_loc,$I_INJ"
    fi
    if [[ $NUM_DIMS -ge 2 ]]; then 
        export J_INJ=`echo $INJ | cut -d',' -f3`
        inj_site_loc="$inj_site_loc,$J_INJ"
    fi
    if [[ $NUM_DIMS -ge 3 ]]; then 
        export K_INJ=`echo $INJ | cut -d',' -f4`
        inj_site_loc="$inj_site_loc,$K_INJ"
    fi
}


NUM_RUNS=100
THRESHOLD=1e-5

function usage {
    echo "usage: $0 [-h] [-f] [-s] [-r R] [-t THRESHOLD] [-b B] [-i INJ] [-d D] [name H L T N]";
    echo "options:"
    echo "    -h, --help           :  Display this menu";
    echo "    -f, --force          :  Force regeneration and recompilation"
    echo "    -s, --do-single      :  Only run a single instance"
    echo "    -r, --num-runs       :  Run each instance R times (default: $NUM_RUNS)"
    echo "    -t, --threshold      :  Checksum expression pair differences above THRESHOLD are treated as"
    echo "                            errors (default: $THRESHOLD)"
    echo "    -b, --bit            :  Bit to flip (0<=B<32)"
    echo "    -i, --inj-site       :  Comma-delimited list 'T_INJ,I_INJ[,J_INJ[,K_INJ]]' of coordinates at"
    echo "                            which the error injection is performed. For a (d)-dimensional stencil"
    echo "                            there must be d+1 values."
    echo "    -d, --num-dimensions :  Number of spatial dimension. Required if injection site unspecified."
    echo "parameters:"
    echo "     H   :  Hyper-trapezoidal height of checksum regions (across time)"
    echo "     L   :  Hyper-trapezoidal ceiling side length of checksum regions (across space)"
    echo "     T   :  Number of time steps to run stencil iteration"
    echo "     N   :  Size of stencil data space dimensions"
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
        -v|--verbose)
            VERBOSE=1
            shift 1
            ;;
        -s|--do-single)
            DO_SINGLE=1
            shift 1
            ;;
        -t|--threshold)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                THRESHOLD=$2
                shift 2
            else
                echo "argument missing for -- $1"
                exit 1
            fi
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
        -b|--bit)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                if [[ $2 -lt 0 || $2 -gt 31 ]]; then
                    echo "error: unsupported bit value B=$2"
                    exit 1
                fi
                B=$2
                shift 2
            else
                echo "argument missing for -- $1"
                exit 1
            fi
            ;;
        -i|--inj-site)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                # ignore any trailing commas
                INJ=`echo $2 | sed 's~,*$~~'`
                commas=`echo $INJ | tr -cd ,`
                NUM_DIMS=${#commas}
                shift 2
            else
                echo "argument missing for -- $1"
                exit 1
            fi
            ;;
        -d|--num-dimensions)
            if [ -n "$2" ] && [ ${2:0:1} != "-" ]; then
                NUM_DIMS=$2
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

echo "#name,H,L,T,N,bit,$(injection_site_header),threshold,detected"
if [[ -n $DO_SINGLE ]]; then
    if [[ -z $INJ && -z $NUM_DIMS ]]; then
        echo "error: must specify either an injection site or number of stencil dimensions"
        exit 1
    fi

    name=$1
    H=$2
    L=$3
    T=$4
    N=$5
    
    if [[ -z $name || -z $H || -z $L || -z $T || -z $N ]]; then
        echo "error: missing some positional parameters"
        echo
        usage
        exit 1
    fi

    if [[ -z $INJ ]]; then INJ=`choose_random_inj_site $T $N $NUM_DIMS`; fi
    if [[ -z $B ]]; then B=$((RANDOM % 32)); fi
    export_injection_site $INJ $B $THRESHOLD
    do_single $name $H $L $T $N 1 $FORCE 2>/dev/null
    exit
fi

# run simple error injection experiment
name=star1d1r
T=500
N=1000000
H=10
NUM_DIMS=1
for L in $(seq 100 100 2000)
do
    for B in $(seq 31 -1 11)
    do
        for r in $(seq 1 $NUM_RUNS)
        do
            INJ=`choose_random_inj_site $T $N $NUM_DIMS`
            export_injection_site $INJ $B $THRESHOLD
            do_single $name $H $L $T $N 1 $FORCE 2>/dev/null
        done
    done
done
