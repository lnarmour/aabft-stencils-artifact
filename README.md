This repository contains the experimental workflow and all artifacts relating to the PACT 2023 conference paper titled, "Automatic Algorithm-Based Fault Tolerance (AABFT) of Stencil Computations".

## References

Title: Automatic Algorithm-Based Fault Tolerance (AABFT) of Stencil Computations

Authors: Louis Narmour, Steven Derrien, Sanjay Rajopadhye

[Archived Artifact](https://doi.org/10.5281/zenodo.8275234)

[Artifact Submission Guidelines](https://github.com/mlcommons/ck/blob/master/docs/artifact-evaluation/submission.md)

## Artifact check-list

* **Compilation:** AlphaZ compiler (provided as java JAR files) and make with gcc
* **Binary:** To be produced on target machine
* **Execution:** Automated via provided command line script
* **Experiments:** Execution time overhead; error injection and detection.
```
$ LOG_FILE=results-overhead.log ./overhead.sh
$ LOG_FILE=results-error-inj.log ./error-injection.sh
```
* **How much disk space required (approximately)?:** ~300 MB
* **How much memory required (approximately)?:** ~12 GB
* **How much time is needed to prepare workflow (approximately)?:** <20 min (to install system dependencies if necessary)
* **How much time is needed to complete experiments (approximately)?:** ~27 hours (15 for overhead experiment + 12 for error injection experiment)
* **Publicly available?:** Yes
* **Code licenses (if publicly available)?:** MIT License

## Description

The `inputs` directory contains Alpha stencil programs used to generate ABFT-hardened C code.
This directory contains the following three scripts:
1. `generate.sh`: generates C code for an input Alpha stencil program and checksum size parameters.
1. `overhead.sh`: generates many C codes for a variety of checksum size parameter values for all provided stencils under the inputs directory, runs overhead experiment, and reports execution time overhead.
1. `error-injection.sh`: generates many C codes for a variety of checksum size parameter values for the star1d1r instance, runs error injection experiment, and reports relationship between checksum size and efficacy.

The overhead and error injection scripts call into `generate.sh`.

## Software prerequisites

Running this requires a linux machine with:
* java 11
* gcc
* make

## Generate C code

The `generate.sh` script can be used to generate C code for a corresponding input stencil and ABFT patch size specification.
This script takes 5 arguments (note the `$` is part of the shell prompt and not the command):
```
$ ./generate.sh 
usage: ./generate.sh stecil_alpha_file system_name H L [output_directory]
parameters:
     stencil_alpha_file :  Input Alpha program implementing a stencil
     system_name        :  Name of the Alpha system
     H                  :  Hyper-trapezoidal height of checksum regions (across time)
     L                  :  Hyper-trapezoidal ceiling side length of checksum regions (across space)
     output_directory   :  directory in which to place the output files (default: ./)

```
For example, the following...
```
$ ./generate.sh inputs/star1d1r.alpha star1d1r 12 200
```
...generates the following subdirectory:
```
star1d1r/
└── 12.200
    ├── codegen
    │   ├── abft
    │   │   ├── Makefile
    │   │   ├── conv.c
    │   │   ├── init.c
    │   │   ├── star1d1r-err.c
    │   │   ├── star1d1r-wrapper.c
    │   │   └── star1d1r.c
    │   └── noabft
    │       ├── Makefile
    │       ├── star1d1r-wrapper.c
    │       └── star1d1r.c
    ├── convolution_kernel.txt
    ├── star1d1r.abft.ab
    ├── star1d1r.abft.alpha
    └── star1d1r.noabft.ab
```
Two codegen sub-directories are produced, one for the baseline input program (denoted as 'noabft') and another for the ABFT-augmented version (denoted 'abft').
Two versions of the ABFT-augmented code are generated, `star1d1r.c` and `star1d1r-err.c` as shown above.
These are identical except the `*-err.c` version contains the error injection harnessing used to perform bit flips.
In the `*-err.c` generated code, the error injection sites (i.e., the particular space-time index at which to simulate the error) are controlled by environment variables, `T_INJ`, `I_INJ`, `J_INJ`, and `K_INJ`.
The bit to be flipped is controlled by the environment variable `BIT`.
These are used by the `error-injection.sh` script, see the corresponding description below.

Compile each version with make using:
```
$ make -C star1d1r/12.200/codegen/abft
$ make -C star1d1r/12.200/codegen/noabft
```

Then run each version, specifying the stencil size parameters `T` and `N` for the number of time steps and spatial dimension size respectively.
For example,
```
$ ./star1d1r/12.200/codegen/abft/star1d1r 1000 1000000
Execution time : 0.912053 sec.
$ ./star1d1r/12.200/codegen/noabft/star1d1r 1000 1000000
Execution time : 0.794213 sec.
```
The overhead can then be taken as the ratio of the two (i.e., 0.912053/0.794213 -> 1.148 -> 14.8%).

## Overhead experiments

The `overhead.sh` script can be used to do everything above automatically for a range of checksum region sizes.
This script has the following usage,
```
./overhead.sh -h
usage: ./overhead.sh [-h] [-f] [-s] [-r R] [name H L T N]
options:
    -h, --help           :  Display this menu
    -f, --force          :  Force regeneration and recompilation
    -s, --do-single      :  Only run a single instance
    -r, --num-runs       :  Run each instance R times (default: 3)
parameters:
     name :  stencil name
     H    :  Hyper-trapezoidal height of checksum regions (across time)
     L    :  Hyper-trapezoidal ceiling side length of checksum regions (across space)
     T    :  Number of time steps to run stencil iteration
     N    :  Size of stencil data space dimensions

Parameters are only required if running a single instance
```
For example, use the following to run a single instance example,
```
$ ./overhead.sh -s star1d1r 12 200 1000 1000000
./star1d1r/12.200/convolution_kernel.txt
./star1d1r/12.200/star1d1r.abft.alpha
./star1d1r/12.200/star1d1r.abft.ab
./star1d1r/12.200/star1d1r.noabft.ab
./star1d1r/12.200/codegen/abft/Makefile
./star1d1r/12.200/codegen/abft/star1d1r-wrapper.c
./star1d1r/12.200/codegen/abft/star1d1r.c
./star1d1r/12.200/codegen/abft/init.c
./star1d1r/12.200/codegen/abft/conv.c
./star1d1r/12.200/codegen/abft/star1d1r-err.c
./star1d1r/12.200/codegen/noabft/Makefile
./star1d1r/12.200/codegen/noabft/star1d1r-wrapper.c
./star1d1r/12.200/codegen/noabft/star1d1r.c
cc star1d1r.c -o star1d1r.o -O3  -std=c99  -I/usr/include/malloc/ -lm -c
cc init.c -o init.o -O3  -std=c99  -I/usr/include/malloc/ -lm -c
cc conv.c -o conv.o -O3  -std=c99  -I/usr/include/malloc/ -lm -c
cc star1d1r-wrapper.c -o star1d1r star1d1r.o init.o conv.o -O3  -std=c99  -I/usr/include/malloc/ -lm
cc star1d1r-err.c -o star1d1r-err.o -O3  -std=c99  -I/usr/include/malloc/ -lm -c
cc star1d1r-wrapper.c -o star1d1r.check star1d1r-err.o init.o conv.o -O3  -std=c99  -I/usr/include/malloc/ -lm -DCHECKING -DRANDOM
cc star1d1r.c -o star1d1r.o -O3  -std=c99  -I/usr/include/malloc/ -lm -c
cc star1d1r-wrapper.c -o star1d1r star1d1r.o  -O3  -std=c99  -I/usr/include/malloc/ -lm
cc star1d1r-wrapper.c -o star1d1r.check star1d1r.o  -O3  -std=c99  -I/usr/include/malloc/ -lm -DCHECKING -DRANDOM
star1d1r,12,200,1000,1000000,abft,0.502640
star1d1r,12,200,1000,1000000,abft,0.459046
star1d1r,12,200,1000,1000000,abft,0.458686
star1d1r,12,200,1000,1000000,noabft,0.402314
star1d1r,12,200,1000,1000000,noabft,0.361933
star1d1r,12,200,1000,1000000,noabft,0.363744
```
This generates the C code using `generate.sh`, compiles the `abft` and `noabft` versions, and runs each version serveral times displaying the execution time for each.

The overhead script can be used to test a variety of checksum sizes on all of the provided input programs to reflect the findings reported in the paper.
The results can be directed to a file using the `LOG_FILE` environment variable.
```
$ LOG_FILE=results-overhead.log ./overhead.sh
```

The 3D stencils, with the problem sizes specified in `overhead.sh`, have a memory footprint of ~11GB, so be sure to use an appropriate machine if you want to run the script as is.
On a machine with 16GB RAM and an Intel(R) Xeon(R) CPU E5-1650 v4 @ 3.60GHz processor, individual program runs can take 200-300 seconds.
Running all of the 1D and 2D examples take 3.5 hours each and the 3D examples takes 8 hours.
Expect the entire script to take 15 hours.

#### Expectation

ABFT-augmented code with small `H` values should have high overhead.
As `H` is increased, the overhead should decrease.

### Error injection experiments

The `error-injection.sh` script can be used to simulate errors via bit flips.
It has the following usage:
```
usage: ./error-injection.sh [-h] [-f] [-s] [-r R] [-t THRESHOLD] [-b B] [-i INJ] [-d D] [name H L T N]
options:
    -h, --help           :  Display this menu
    -f, --force          :  Force regeneration and recompilation
    -s, --do-single      :  Only run a single instance
    -r, --num-runs       :  Run each instance R times (default: 100)
    -t, --threshold      :  Checksum expression pair differences above THRESHOLD are treated as
                            errors (default: 1e-5)
    -b, --bit            :  Bit to flip (0<=B<32)
    -i, --inj-site       :  Comma-delimited list 'T_INJ,I_INJ[,J_INJ[,K_INJ]]' of coordinates at
                            which the error injection is performed. For a (d)-dimensional stencil
                            there must be d+1 values.
    -d, --num-dimensions :  Number of spatial dimension. Required if injection site unspecified.
parameters:
     H   :  Hyper-trapezoidal height of checksum regions (across time)
     L   :  Hyper-trapezoidal ceiling side length of checksum regions (across space)
     T   :  Number of time steps to run stencil iteration
     N   :  Size of stencil data space dimensions

Parameters are only required if running a single instance
```

For example, the following...
```
$ ./error-injection.sh -s -b 27 -i 50,2000 star1d1r 10 100 1000 1000000
```
...generates the star1d1r instance with `H=10` and `L=100`.
Then it runs the stencil with size parameters `T=1000` and `N=1000000`.
At the iteration `(t,i)=(50,2000)`, bit 27 is flipped in the value in the answer variable.
These are passed via the environment variables described above.
After the main computation finishes, the values of the checksum expression pairs are inspected.
The number of checksum expression pairs that have a value above the detection threshold is reported.
For this example, the following output is produced...
```
#name,H,L,T,N,bit,t_inj,i_inj,threshold,detected
star1d1r,10,100,1000,1000000,27,50,2000,1e-5,1
```
...which indicates that a single checksum expression pair was observed with a difference above the threshold `1e-5`.

The threshold can be changed with the `-t` parameter.
For example, setting the threshold to something unrealistically small, like `1e-9` for example with...
```
$ ./error-injection.sh -s -b 27 -i 50,2000 -t 1e-9 star1d1r 10 100 1000 1000000
#name,H,L,T,N,bit,t_inj,i_inj,threshold,detected
star1d1r,10,100,1000,1000000,27,50,2000,1e-9,833677
```
...means that 833677 checksum expression pairs (i.e., all of them) have a value above `1e-9`.
This is meaningless, of course, since the floating-point round-off errors are near `1e-06` but it illustrates what the script is doing.
The larger the detection threshold, the more confidence we can have that observing a checksum expression pair value above the threshold corresponds to a real error that would produce an incorrect result.

If no arguments are passed, then the script tests a variety of checksum patch sizes across all possible meaningful bit flip positions (11-31) for the `star1d1r` stencil.
Errors injected below the 11'th least signficant bit are almost never observable, so they are omitted.
Each combination of checksum patch size and bit flip position is run 100 times.
This can be used to validate the results reported in Figure 10 of the paper.
```
$ ./error-injection.sh 
#name,H,L,T,N,bit,t_inj,i_inj,threshold,detected
star1d1r,10,100,500,1000000,31,364,6765,1e-5,1
star1d1r,10,100,500,1000000,31,427,25332,1e-5,1
star1d1r,10,100,500,1000000,31,64,31258,1e-5,1
star1d1r,10,100,500,1000000,31,487,6025,1e-5,1
star1d1r,10,100,500,1000000,31,378,18195,1e-5,1
...
```

Like the overhead script, you can output the results to a log file with the `LOG_FILE` environment variable:
```
LOG_FILE=results-error-inj.log ./error-injection.sh
```

#### Expectations

As the checksum patch size grows larger, the frequency at which errors can be detected for a given bit flip position decreases.
On a machine with 16GB RAM and an Intel(R) Xeon(R) CPU E5-1650 v4 @ 3.60GHz processor, the `error-injection.sh` script takes ~12 hours to run.
