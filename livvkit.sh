#!/usr/bin/env bash

# Purpose: Analyze LIVVKit-friendly timeseries
# Prequisites: NCO

# Usage:
# ~/livvkit/livvkit.sh 
# ~/livvkit/livvkit.sh ${DATA}/livvkit/v2.1.r05.BGWCYCL20TR-steve_2005_2014.nc
# ~/livvkit/livvkit.sh > ~/foo.txt 2>&1 & # 

# Production:
# screen # Start screen
# ~/livvkit/livvkit.sh > ~/foo.txt 2>&1 &
# Ctl-A D # Detach screen
# tail ~/foo.txt # Monitor progress
# screen -ls # List screens
# screen -r <ID> # Re-attach screen

# Locations of final processed LIVVkit data:
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

function fnc_usg_prn { # NB: dash supports fnc_nm (){} syntax, not function fnc_nm{} syntax
    # Print usage
    printf "${fnt_rvr}Basic usage:\n"
    printf "${fnt_nrm} ${fnt_bld}${spt_nm} fl_in${fnt_nrm} # Specify LIVVkit input file\n"
    printf "\n"
    printf "Examples: ${fnt_bld}${spt_nm} ${fl_in}\n"
    exit 1
} # !fnc_usg_prn()

# Check argument number and complain accordingly
arg_nbr=$#
if [ ${arg_nbr} -eq 0 ]; then
  fnc_usg_prn
fi # !arg_nbr

# Set default values and paths
dbg_lvl=1
drc_lvk="${drc_root}/livvkit"
drc_ts="${drc_root}/livvkit/ts"
drc_clm="${drc_root}/livvkit/clm"

# Derive per-experiment values
fll_nm=$1
drc_in="$(dirname ${fll_nm})"
fl_in="$(basename ${fll_nm})"
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG drc_in = ${drc_in}"
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG fl_in = ${fl_in}"
fl_rx='^(.*)_([0123456789][0123456789][0123456789][0123456789])_([0123456789][0123456789][0123456789][0123456789]).nc$'
if [[ "${fl_in}" =~ ${fl_rx} ]]; then
    caseid=${BASH_REMATCH[1]}
    yr_srt=${BASH_REMATCH[2]}
    yr_end=${BASH_REMATCH[3]}
else
    echo "ERROR: Input file name does not match regular expression '${fl_rx}'"
    echo "HINT: Input file name must have form like 'caseid_YYYY1_YYYY2.nc'"
fi # !fl_in
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG caseid = ${caseid}, yr_srt = ${yr_srt}, yr_end = ${yr_end}"

# Define variables
msk_rsn='r05'
yyyy_srt=`printf "%04d" ${yr_srt}`
yyyy_end=`printf "%04d" ${yr_end}`
yyyy_srt_end="${yyyy_srt}_${yyyy_end}" # 1980_2020
yyyymm_srt_end_out="${yyyy_srt}01_${yyyy_end}12" # 198001_202012

if [ ${caseid} = 'v2.1.r025.IGERA5ELM_MLI-deep_firn' ]; then
    msk_rsn='r025'
fi # !caseid
[[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG msk_rsn = ${msk_rsn}"

[[ ${dbg_lvl} -ge 1 ]] && date_tm=$(date +"%s")
printf "Begin Step 1: Add Icemask to input file\n\n"

# Loop over ice sheets
for ish_nm in ais gis ; do
    
    fl_ish=${fl_in/${yyyy_srt_end}/${ish_nm}}

    fl_avg=${fl_ish/${ish_nm}/${ish_nm}_txy}
    fl_tms=${fl_ish/${ish_nm}/${ish_nm}_t}
    fl_xy=${fl_ish/${ish_nm}/${ish_nm}_xy}

    if [ ${ish_nm} = 'ais' ]; then
	hyp_arg='-d lat,-90.,-60.0'
    fi # !ish_nm
    if [ ${ish_nm} = 'gis' ]; then
	hyp_arg='-d lat,59.125,83.875 -d lon,-73.25,-10.75'
    fi # !ish_nm
    [[ ${dbg_lvl} -ge 1 ]] && echo "${spt_nm}: DEBUG ish_nm = ${ish_nm}, hyp_arg = ${hyp_arg}"

    # Copy input file to file with ice-sheet name and work on that
    cmd_cp="/bin/cp ${drc_in}/${fl_in} ${drc_in}/${fl_ish}"
    echo ${cmd_cp}
    eval ${cmd_cp}

    # Add Icemask to input file
    cmd_apn="ncks -A -C -v Icemask ${DATA}/grids/msk_${ish_nm}_rcm_${msk_rsn}.nc ${drc_in}/${fl_ish}"
    echo ${cmd_apn}
    eval ${cmd_apn}

    # Hyperslab LIVVkit file with Icemask
    cmd_hyp="ncks -O ${hyp_arg} ${drc_in}/${fl_ish} ${drc_in}/${fl_ish}"
    echo ${cmd_hyp}
    eval ${cmd_hyp}

    # Add area_mask and derived variables
    cmd_drv="ncap2 -O -s 'area*=1.0e6;area@units=\"meter2\";area_mask=area*Icemask;area_ttl=area_mask.sum();CMB=SNOW+RAIN-QRUNOFF-QSOIL;CMB@units=\"mm s-1\";CMB@long_name=\"Climatic Mass Balance Rate (including snowpack)\";QSTORAGE=SNOW_SOURCES-SNOW_SINKS;QSTORAGE@units=\"mm s-1\";QSTORAGE@long_name=\"Change in snowpack mass\";' ${drc_in}/${fl_ish} ${drc_in}/${fl_ish}"
    echo ${cmd_drv}
    eval ${cmd_drv}

# Compute area-weighted timeseries
    cmd_xy="ncwa -O -6 -a lat,lon -w area_mask ${drc_in}/${fl_ish} ${drc_in}/${fl_xy}"
    echo ${cmd_xy}
    eval ${cmd_xy}

# Compute time-weighted region
    if false; then
	cmd_t="ncwa -O -6 -a lat,lon -w area_mask ${drc_in}/${fl_ish} ${drc_in}/${fl_t}"
	echo ${cmd_t}
	eval ${cmd_t}
    fi # !false
    
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
