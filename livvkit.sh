#!/usr/bin/env bash

# Purpose: Analyze LIVVkit-friendly timeseries
# Prerequisites: Bash, NCO
# Script could use other shells, e.g., dash (Debian default) after rewriting function definitions and loops
# Debug with 'bash -x livvkit.sh --dbg=dbg_lvl' where 0 <= dbg_lvl <= 5

# Usage:
# ~/livvkit/livvkit.sh --dbg=0 --no_cahd ${DATA}/livvkit/v2.1.r05.BGWCYCL20TR-steve_2005_2014.nc
# ~/livvkit/livvkit.sh --no_cahd /lcrc/group/e3sm/ac.zender/scratch/livvkit/v3.LR.piControl.I.hex_eqm_0001_0100.nc
# ~/livvkit/livvkit.sh --do_cahd /lcrc/group/e3sm/ac.zender/scratch/livvkit/v3.LR.piControl.I.hex_eqm_0101_0200.nc
# ~/livvkit/livvkit.sh /global/cfs/cdirs/e3sm/zender/livvkit/v2.1.r025.IGERA5ELM_MLI-deep_firn_1980_2020.nc
# ~/livvkit/livvkit.sh ${DATA}/livvkit/v2.1.r05.BGWCYCL20TR-steve_2005_2014.nc > ~/foo.txt 2>&1 &

# Production:
# screen # Start screen
# fl_in=${DATA}/livvkit/v2.1.r05.BGWCYCL20TR-steve_2005_2014.nc
# ~/livvkit/livvkit.sh --dbg=- --do_cahd ${fl_in} > ~/foo.txt 2>&1 &
# Ctl-A D # Detach screen
# tail ~/foo.txt # Monitor progress
# screen -ls # List screens
# screen -r <ID> # Re-attach screen

# Locations of input and final processed LIVVkit data:
# /global/cfs/cdirs/e3sm/zender/livvkit
# /lcrc/group/e3sm/ac.zender/scratch/livvkit

spt_src="${BASH_SOURCE[0]}"
[[ -z "${spt_src}" ]] && spt_src="${0}" # Use ${0} when BASH_SOURCE is unavailable (e.g., dash)
while [ -h "${spt_src}" ]; do # Recursively resolve ${spt_src} until file is no longer a symlink
    drc_spt="$( cd -P "$( dirname "${spt_src}" )" && pwd )"
    spt_src="$(readlink "${spt_src}")"
    [[ ${spt_src} != /* ]] && spt_src="${drc_spt}/${spt_src}" # If ${spt_src} was relative symlink, resolve it relative to path where symlink file was located
done
cmd_ln="${spt_src} ${@}"
drc_spt="$( cd -P "$( dirname "${spt_src}" )" && pwd )"
spt_nm=$(basename ${spt_src}) # [sng] Script name (unlike $0, ${BASH_SOURCE[0]} works well with 'source <script>')

# Human-readable summary
date_srt=$(date +"%s")
if [ ${vrb_lvl} -ge ${vrb_3} ]; then
    printf "LIVVkit timeseries analysis invoked with command:\n"
    echo "${cmd_ln}"
fi # !vrb_lvl

if [ "${LMOD_SYSTEM_NAME}" = 'perlmutter' ]; then
    drc_root='/global/cfs/cdirs/fanssie' # Perlmutter
elif [[ "${HOSTNAME}" =~ 'chrlogin' ]]; then
    drc_root='/lcrc/group/e3sm/ac.zender/scratch' # Chrysalis
elif [ "${HOSTNAME}" = 'spectral' ]; then
    drc_root="${DATA}" # Spectral
else
    echo "${spt_nm}: ERROR Invalid \${drc_root} = ${drc_root}"
    exit 1
fi # !HOSTNAME

# When running in a terminal window (not in an non-interactive batch queue)...
if [ -n "${TERM}" ]; then
    # Set fonts for legibility
    if [ -x /usr/bin/tput ] && tput setaf 1 &> /dev/null; then
	fnt_bld=`tput bold` # Bold
	fnt_nrm=`tput sgr0` # Normal
	fnt_rvr=`tput smso` # Reverse
	fnt_tlc=`tput sitm` # Italic
    else
	fnt_bld="\e[1m" # Bold
	fnt_nrm="\e[0m" # Normal
	fnt_rvr="\e[07m" # Reverse
	fnt_tlc="\e[3m" # Italic
    fi # !tput
fi # !TERM

# Defaults for command-line options and some derived variables
# Modify these defaults to save typing later
dbg_lvl=0 # [enm] Debugging level
drc_lvk="${drc_root}/livvkit" # [sng] Directory for LIVVkit-input timeseries
drc_ts="${drc_root}/livvkit/ts" # [sng] Directory for timeseries output by this analysis
drc_clm="${drc_root}/livvkit/clm" # [sng] Directory climatologies output by this analysis
flg_do_cp_apn_hyp_drv='Yes' # [flg] Perform (time-consuming) copy, append, hyperslab, derive tasks

function fnc_usg_prn { # NB: dash supports fnc_nm (){} syntax, not function fnc_nm{} syntax
    # Print usage
    printf "${fnt_rvr}Basic usage:\n"
    printf "${fnt_nrm} ${fnt_bld}${spt_nm} fl_in${fnt_nrm} # Specify LIVVkit input file\n"
    echo "Command-line options [long-option synonyms in ${fnt_tlc}italics${fnt_nrm}]:"
    echo " ${fnt_bld}--cahd${fnt_nrm} Link E3SM-climo to AMWG-climo filenames [${fnt_tlc}amwg_links, AMWG_link${fnt_nrm}]"
    echo "${fnt_rvr}-d${fnt_nrm} ${fnt_bld}dbg_lvl${fnt_nrm}  Debug level (default ${fnt_bld}${dbg_lvl}${fnt_nrm}) [${fnt_tlc}dbg_lvl, dbg, debug, debug_level${fnt_nrm}]"
    printf "\n"
    printf "${fnt_rvr}Examples:${fnt_nrm}\n${fnt_bld}${spt_nm} ${DATA}/livvkit/v2.1.r05.BGWCYCL20TR-steve_2005_2014.nc ${fnt_nrm}# Typical LIVVkit processing\n"
    printf "${fnt_bld}${spt_nm} --dbg=1 ${DATA}/livvkit/v2.1.r05.BGWCYCL20TR-steve_2005_2014.nc ${fnt_nrm}# Debugging = 1\n"
    echo " ${fnt_bld}--do_cahd${fnt_nrm}   Perform (time-consuming) copy, append, hyperslab, derive tasks. do_cp_apn_hyp_drv${fnt_nrm}]"
    echo " ${fnt_bld}--no_cahd${fnt_nrm}   Do not perform (time-consuming) copy, append, hyperslab, derive tasks. no_cp_apn_hyp_drv${fnt_nrm}]"
    exit 1
} # !fnc_usg_prn()

function trim_leading_zeros {
    # Purpose: Trim leading zeros from string representing an integer
    # Why, you ask? Because Bash treats zero-padded integers as octal!
    # This is surprisingly hard to workaround
    # My workaround is to remove leading zeros prior to arithmetic
    # Usage: trim_leading zeros ${sng}
    sng_trm=${1} # [sng] Trimmed string
    # Use Bash 2.X pattern matching to remove up to three leading zeros, one at a time
    sng_trm=${sng_trm##0} # NeR98 p. 99
    sng_trm=${sng_trm##0}
    sng_trm=${sng_trm##0}
    # If all zeros removed, replace with single zero
    if [ ${sng_trm} = '' ]; then 
	sng_trm='0'
    fi # !sng_trm
} # !trim_leading_zeros()

# Check argument number and complain accordingly
arg_nbr=$#
if [ ${arg_nbr} -eq 0 ]; then
    fnc_usg_prn
fi # !arg_nbr

# Parse command-line options:
# http://stackoverflow.com/questions/402377/using-getopts-in-bash-shell-script-to-get-long-and-short-command-line-options
# http://tuxtweaks.com/2014/05/bash-getopts
while getopts :d:-: OPT; do
    case ${OPT} in
	d) dbg_lvl="${OPTARG}" ;; # Debugging level
	-) LONG_OPTARG="${OPTARG#*=}"
	   case ${OPTARG} in
	       # Hereafter ${OPTARG} is long argument key, and ${LONG_OPTARG}, if any, is long argument value
	       # Long options with no argument, no short option counterpart
	       # Long options with argument, no short option counterpart
	       # Long options with short counterparts, ordered by short option key
	       dbg_lvl=?* | dbg=?* | debug=?* | debug_level=?* ) dbg_lvl="${LONG_OPTARG}" ;; # -d # Debugging level
	       cahd | cp_apn_hyp_drv ) flg_do_cp_apn_hyp_drv=${LONG_OPTARG} ;; # # Perform (time-consuming) copy, append, hyperslab, derive tasks
	       do_cahd | do_cp_apn_hyp_drv ) flg_do_cp_apn_hyp_drv='Yes' ;; # # Perform (time-consuming) copy, append, hyperslab, derive tasks
	       do_cahd=?* | do_cp_apn_hyp_drv=?* ) echo "No argument allowed for --${OPTARG switch}" >&2; exit 1 ;; # # Perform (time-consuming) copy, append, hyperslab, derive tasks
	       no_cahd | no_cp_apn_hyp_drv ) flg_do_cp_apn_hyp_drv='No' ;; # # Perform (time-consuming) copy, append, hyperslab, derive tasks
	       no_cahd=?* | no_cp_apn_hyp_drv=?* ) echo "No argument allowed for --${OPTARG switch}" >&2; exit 1 ;; # -l # Perform (time-consuming) copy, append, hyperslab, derive tasks
               '' ) break ;; # "--" terminates argument processing
               * ) printf "\nERROR: Unrecognized option ${fnt_bld}--${OPTARG}${fnt_nrm}\n" >&2; fnc_usg_prn ;;
	   esac ;; # !OPTARG
	\?) # Unrecognized option
	    printf "\nERROR: Option ${fnt_bld}-${OPTARG}${fnt_nrm} not recognized\n" >&2
	    fnc_usg_prn ;;
    esac # !OPT
done # !getopts
shift $((OPTIND-1)) # Advance one argument
psn_nbr=$# # [nbr] Number of positional parameters (besides \$0)
if [ ${psn_nbr} -gt 1 ]; then
    echo "ERROR: Found ${psn_nbr} positional parameters, expected only one (the input file name)"
    echo "HINT: Provide input file name after all options as first positional parameter"
fi # !psn_nbr
for ((psn_idx=1;psn_idx<=psn_nbr;psn_idx++)); do
	fll_nm=${!psn_idx} # [sng] Full (directory+file) input name
	fl_nbr=${psn_nbr}
done # !psn_idx

# Derive per-experiment values
drc_in="$(dirname ${fll_nm})" # [sng] Input directory
fl_in="$(basename ${fll_nm})" # [sng] Input file
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG drc_in = ${drc_in}"
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG fl_in = ${fl_in}"
fl_rx='^(.*)_([0123456789][0123456789][0123456789][0123456789])_([0123456789][0123456789][0123456789][0123456789]).nc$' # [sng] Regular expression for input filenames of form caseid_YYYY1_YYYY2.nc
if [[ "${fl_in}" =~ ${fl_rx} ]]; then
    caseid=${BASH_REMATCH[1]}
    yr_srt=${BASH_REMATCH[2]}
    yr_end=${BASH_REMATCH[3]}
else
    echo "ERROR: Input file name does not match regular expression '${fl_rx}'"
    echo "HINT: Input file name must have form like 'caseid_YYYY1_YYYY2.nc'"
    exit 1
fi # !fl_in
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG caseid = ${caseid}, yr_srt = ${yr_srt}, yr_end = ${yr_end}"

# Derive dates
trim_leading_zeros ${yr_srt}
yr_srt_rth=${sng_trm}
yyyy_srt=`printf "%04d" ${yr_srt_rth}`
trim_leading_zeros ${yr_end}
yr_end_rth=${sng_trm}
yyyy_end=`printf "%04d" ${yr_end_rth}`
yyyy_srt_end="${yyyy_srt}_${yyyy_end}" # 1980_2020
yyyymm_srt_end_out="${yyyy_srt}01_${yyyy_end}12" # 198001_202012
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG yyyy_srt = ${yyyy_srt}, yyyy_end = ${yyyy_end}, yyyy_srt_end = ${yyyy_srt_end}"

# Define variables
msk_rsn='r05' # [sng] Resolution of ELM experiment in ice sheet masks
if [ ${caseid} = 'v2.1.r025.IGERA5ELM_MLI-deep_firn' ]; then
    msk_rsn='r025'
fi # !caseid
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG msk_rsn = ${msk_rsn}"

[[ ${dbg_lvl} -ge 1 ]] && date_tm=$(date +"%s")
printf "Begin Analysis Workflow\n\n"

# Loop over ice sheets
for ish_nm in ais gis ; do
    
    fl_ish="${fl_in/${yyyy_srt_end}/${yyyy_srt_end}_${ish_nm}}" # [sng] File original data plus ice-sheet specific Icemask and appended/derived fields
    if [ ${fl_in} = ${fl_ish} ]; then
	echo "ERROR: fl_in == fl_ish"
	echo "DEBUG: yyyy_srt_end = ${yyyy_srt_end}, ish_nm=${ish_nm}"
	exit 1
    fi # !fl_in
    
    fl_avg="${fl_ish/${ish_nm}/${ish_nm}_txy}" # [sng] File containing spatio-temporal average
    fl_tms="${fl_ish/${ish_nm}/${ish_nm}_t}" # [sng] File containing temporal average
    fl_xy="${fl_ish/${ish_nm}/${ish_nm}_xy}" # [sng] File containing spatial average
    
    hyp_arg='' # [sng] ncks hyperslab argument for ice-sheet bounding box
    if [ ${ish_nm} = 'ais' ]; then
	hyp_arg='-d lat,-90.,-60.0'
    fi # !ish_nm
    if [ ${ish_nm} = 'gis' ]; then
	hyp_arg='-d lat,59.125,83.875 -d lon,-73.25,-10.75'
    fi # !ish_nm
    [[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG ish_nm = ${ish_nm}, hyp_arg = ${hyp_arg}"
    
    if [ ${flg_do_cp_apn_hyp_drv} = 'Yes' ]; then
	printf "Step 1: Copy input file to file with ice-sheet name and work on that ...\n"
	cmd_cp="/bin/cp ${drc_in}/${fl_in} ${drc_in}/${fl_ish}"
	echo ${cmd_cp}
	eval ${cmd_cp}
	
	printf "Step 2: Add Icemask to input file ...\n"
	cmd_apn="ncks -A -C -v Icemask ${DATA}/grids/msk_${ish_nm}_rcm_${msk_rsn}.nc ${drc_in}/${fl_ish}"
	echo ${cmd_apn}
	eval ${cmd_apn}
	
	printf "Step 3: Hyperslab LIVVkit file with Icemask to current ice sheet...\n"
	cmd_hyp="ncks -O ${hyp_arg} ${drc_in}/${fl_ish} ${drc_in}/${fl_ish}"
	echo ${cmd_hyp}
	eval ${cmd_hyp}

	if true; then
	    printf "Step 3: Add area_mask weight and derive other variables ...\n"
	    cmd_drv="ncap2 -O -s 'area*=1.0e6;area@units=\"meter2\";area_mask=area*Icemask;area_ttl=area_mask.sum();CMB=SNOW+RAIN-QRUNOFF-QSOIL;CMB@units=\"mm s-1\";CMB@long_name=\"Climatic Mass Balance Rate (including snowpack)\";QSTORAGE=SNOW_SOURCES-SNOW_SINKS;QSTORAGE@units=\"mm s-1\";QSTORAGE@long_name=\"Change in snowpack mass\";' ${drc_in}/${fl_ish} ${drc_in}/${fl_ish}"
	    echo ${cmd_drv}
	    eval ${cmd_drv}
	fi # !true

    else # !flg_do_cp_apn_hyp_drv
	printf "Skipping time-consuming Steps 1-4: copy, append, hyperslab, and derive steps...\n"
    fi # !flg_do_cp_apn_hyp_drv

    printf "Step 5: Compute area-weighted timeseries ...\n"
    cmd_xy="ncwa -O -a lat,lon -w area_mask ${drc_in}/${fl_ish} ${drc_in}/${fl_xy}"
    echo ${cmd_xy}
    eval ${cmd_xy}

    printf "Step 6: Compute time-mean region ...\n"
    cmd_tms="ncra -O -d time,,,12,12 --per_record_weights --wgt 31,28,31,30,31,30,31,31,30,31,30,31 ${drc_in}/${fl_ish} ${drc_in}/${fl_tms}"
    echo ${cmd_tms}
    eval ${cmd_tms}
    
done # !ish_nm

if [ ${dbg_lvl} -ge 1 ]; then
    date_crr=$(date +"%s")
    date_dff=$((date_crr-date_tm))
    printf "Elapsed time to analyze LIVVkit timeseries $((date_dff/60))m$((date_dff % 60))s\n\n"
fi # !dbg

date_end=$(date +"%s")
printf "Completed LIVVkit analysis at `date`\n"
date_dff=$((date_end-date_srt))
echo "Elapsed time $((date_dff/60))m$((date_dff % 60))s"
