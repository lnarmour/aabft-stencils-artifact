#!/bin/bash

set -e

function cleanup {
    exit_code=$?
    if [[ -n "$system_name" ]]; then
        dir="./$out/$system_name"
    fi
    if [[ $exit_code != 0 && -d $dir ]]; then
        rm -rf "$dir"
    fi
}
trap cleanup EXIT

function usage {
    echo "usage: $0 stecil_alpha_file system_name H L [output_directory]";
    echo "parameters:"
    echo "     stencil_alpha_file :  Input Alpha program implementing a stencil"
    echo "     system_name        :  Name of the Alpha system"
    echo "     T                  :  Hyper-trapezoidal height of checksum regions (across time)"
    echo "     N                  :  Hyper-trapezoidal ceiling side length of checksum regions (across space)"
    echo "     output_directory   :  directory in which to place the output files (default: ./)"
    echo ""
}

SCRIPT_DIR=`dirname -- $0`

if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]; then
    usage
    exit 1
fi

stencil_file=$1
system_name=$2
ct=$3
cjx=$4
if [[ -z "$5" ]]; then
    out="."
else
    out=$5
fi

function assert_file_exists {
    f=$1
    if [[ ! -f $f ]]; then
        echo "error: failed to create output file $f"
        exit 1
    fi
    ls $f
}

function run_abft_analysis {
    java -cp $SCRIPT_DIR/phase1.jar alpha.model.abft.AABFTInterpreter $stencil_file $ct $cjx $out
    assert_file_exists $out/$system_name/$ct.$cjx/convolution_kernel.txt
    assert_file_exists $out/$system_name/$ct.$cjx/$system_name.abft.alpha
    assert_file_exists $out/$system_name/$ct.$cjx/$system_name.abft.ab
    assert_file_exists $out/$system_name/$ct.$cjx/$system_name.noabft.ab
}

function gen_c {
    version=$1
    java -cp $SCRIPT_DIR/phase2.jar alpha.model.abft.codegen.Compile \
        $out/$system_name/$ct.$cjx/$system_name.$version.ab \
        $ct \
        $cjx \
        $out/$system_name/$ct.$cjx/convolution_kernel.txt \
        $out/$system_name/$ct.$cjx/codegen/$version

    assert_file_exists $out/$system_name/$ct.$cjx/codegen/$version/Makefile
    assert_file_exists $out/$system_name/$ct.$cjx/codegen/$version/$system_name-wrapper.c
    assert_file_exists $out/$system_name/$ct.$cjx/codegen/$version/$system_name.c
    if [[ $version == 'abft' ]]; then
        assert_file_exists $out/$system_name/$ct.$cjx/codegen/$version/init.c
        assert_file_exists $out/$system_name/$ct.$cjx/codegen/$version/conv.c
        assert_file_exists $out/$system_name/$ct.$cjx/codegen/$version/$system_name-err.c
    fi
}

# Note:
#  - The transformations here use "Alpha" and "AlphaZ"
#  - Alpha is a newer version of AlphaZ and where all of the ABFT analysis is done
#  - Alpha has no code generator, so the resulting ABFT-augmented program is
#    pretty printed to AlphaZ so that the AlphaZ code generator can be called.

run_abft_analysis
gen_c abft 2> /dev/null
gen_c noabft 2> /dev/null
