#!/usr/bin/env bash

# Set bash strict mode (see: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/)
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# Usage
usage() {
  cat << EOF

Usage: $(basename "${BASH_SOURCE[0]}") [-h] recondir voldesc

Create (and run) command to perform slice-to-volume reconstrution (SVR) on stacks of time-averaged images 
using SVRTK application reconstructCardiac.

Expects directory structure with input stacks and masks as follows: 

    recondir
    ├── data
    │   ├── s*_dc_ab.nii.gz
    │   ├── force_exclude_frame.txt
    │   ├── force_exclude_slice.txt
    │   ├── force_exclude_stack.txt
    │   ├── slice_thickness.txt
    │   └── tgt_stack_no.txt
    └── mask
        └── mask_chest.nii.gz

This helper script creates a reconstruction command script in output directory recondir/voldesc/recon.bash 
and (optionally) runs the reconstruction.

Available options:

--resolution      Isotropic resolution of reconstructed volume
--nmc             Number of motion-correction iterations
--nsr             Number of super-resolution reconstruction iterations
--nsrlast         Number of super-resolution reconstruction iterations following last motion-correction iteration
--noeval          Do not evaluate the reconstruction commands
--help            Print this help and exit

EOF
  exit
}

# Parse Input Parameters
parse_params() {
  
  ORIG_PATH=$(pwd)

  # default values
  RESOLUTION=1.25
  NMC=6
  NSR=10
  NSRLAST=20
  NUMCARDPHASE=1
  EVALFLAG=1

  # if no arguments, show usage and exit
  if [ $# -eq 0 ] ; then
    usage
  fi

  # parse flags and parameter inputs 
  while :; do
    case "${1-}" in
    --help) usage ;;
    --resolution)
      RESOLUTION="${2-}"
      shift
      ;;
    --nmc)
      NMC="${2-}"
      shift
      ;;
    --nsr)
      NSR="${2-}"
      shift
      ;;
    --nsrlast)
      NSRLAST="${2-}"
      shift
      ;;
    --noeval) EVALFLAG=0 ;;
    -?*) echo "Unknown option: $1" && exit;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # check required arguments and parameters
  [[ ${#args[@]} -ne 2 ]] && echo "Missing script argument(s); expected two arguments" && exit

  # assign positional arguments to variables
  RECONDIR=$1
  VOLDESC=$2

  return 0
}

# Cleanup
cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  
  # reset working directory
  cd "$ORIG_PATH"

}

# ================================= MAIN SCRIPT =================================


# Parse Parameters

parse_params "$@"


# Check that Recon Directory Exists

if [ ! -d "$RECONDIR" ]; then
  echo directory "$RECONDIR" does not exist
  exit 1
else


# Manage Paths

RECONVOLDIR=$RECONDIR/$VOLDESC
mkdir -p "$RECONVOLDIR"
cd "$RECONVOLDIR"

echo RECON DC VOLUME
echo "$RECONVOLDIR"


# Variables 

RECON=$VOLDESC.nii.gz
STACKS="../data/s*_dc_ab.nii.gz"
THICKNESS=$(cat ../data/slice_thickness.txt)
MASKDCVOL="../mask/mask_chest.nii.gz"
TGTSTACKNO=$(cat ../data/tgt_stack_no.txt)
EXCLUDESTACKFILE="../data/force_exclude_stack.txt"
EXCLUDESLICEFILE="../data/force_exclude_slice.txt"
STACKDOFDIR="stack_transformations"
DOFOUTDIR="slice_transformations"

echo reconstructing DC volume: "$RECONVOLDIR"/"$RECON"


# Setup

ITER=$(($NMC+1))
NUMSTACK=$(ls ../data/s*_dc_ab.nii.gz | wc -w);
EXCLUDESTACK=$(cat $EXCLUDESTACKFILE)
NUMEXCLUDESTACK=$(eval "wc -w $EXCLUDESTACKFILE | awk -F' ' '{print \$1}'" )
EXCLUDESLICE=$(cat $EXCLUDESLICEFILE)
NUMEXCLUDESLICE=$(eval "wc -w $EXCLUDESLICEFILE | awk -F' ' '{print \$1}'" )
echo "   target stack no.: ""$TGTSTACKNO"


# Reconstruct DC Volume

CMD="mirtk reconstructCardiac $RECON $NUMSTACK $STACKS -thickness $THICKNESS -stack_registration -target_stack $TGTSTACKNO -mask $MASKDCVOL -iterations $ITER -rec_iterations $NSR -rec_iterations_last $NSRLAST -resolution $RESOLUTION -force_exclude_stack $NUMEXCLUDESTACK $EXCLUDESTACK -force_exclude_sliceloc $NUMEXCLUDESLICE $EXCLUDESLICE -numcardphase $NUMCARDPHASE -no_robust_statistics -debug > log-main.txt"
echo DC volume reconstruction command: "$CMD"
echo "$CMD" > recon.bash
chmod u+x recon.bash  # ensure script is executable by user

# Clean Up Files

CMD="mkdir -p $STACKDOFDIR; mv stack-transformation0*.dof $STACKDOFDIR;"
echo $CMD >> recon.bash

CMD="mkdir -p $DOFOUTDIR; mv transformation0*.dof $DOFOUTDIR;"
echo $CMD >> recon.bash

CMD="mkdir -p sr_iterations; mv *_mc*sr* sr_iterations;"
echo $CMD >> recon.bash


# Run Recon

if [[ $EVALFLAG -eq 1 ]]; then
  echo "running volume reconstruction: recon.bash"
  ./recon.bash
  echo "volume reconstruction complete"
else
  echo "volume reconstruction script (recon.bash) created, but not evaluated"
fi


# Finish

fi

