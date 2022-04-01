#!/bin/bash

# Tonton Jo - 2021
# Join me on Youtube: https://www.youtube.com/c/tontonjo

# This scripts aim to convert H265 HDR content to H264 SDR while trying to keep HDR colors using Tonemap
# It will look in $inputpath for HDR content and convert them to x264 SDR to $outputpath

# Prerequisits:
# A working GPU decoding setup in jellyfin
# Install needed dependencies to have tonemap
# echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list
# apt-get update
# apt-get install aptitude
# aptitude install nvidia-opencl-icd

# Usage:
# Put script in a jellyfin container accessible folder
# Edit path to match your needs and environement
# make it executable "docker exec jellyfin chmod +x /media/HDRtoSDR_converter.sh"
# run it executable "docker exec jellyfin /media/HDRtoSDR_converter.sh"

# Sources: 
# https://unix.stackexchange.com/questions/9496/looping-through-files-with-spaces-in-the-names
# https://video.stackexchange.com/questions/22059/how-to-identify-hdr-video
# https://github.com/jellyfin/jellyfin/pull/3442#issuecomment-700368424

# ------------- Settings -------------------------
inputpath=/media/films
outputpath=/media/unmatic
# ---------- END OF SETTINGS ---------------------

# ---------------- ENV VARIABLE -----------------------
ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg
ffprobe=/usr/lib/jellyfin-ffmpeg/ffprobe
# Allow to handle spaces in "for" loop
OIFS="$IFS"
IFS=$'\n'
# ---------------- ENV VARIABLE -----------------------

# movies=$(ls | grep \.mkv)
for mkv in `ls "$inputpath" | grep \.mkv`
do
echo "$mkv"
COLORS=$($ffprobe -show_streams -v error "$inputpath/$mkv" |egrep "^color_transfer|^color_space=|^color_primaries=" |head -3)
for C in $COLORS; do
        if [[ "$C" = "color_space="* ]]; then
                COLORSPACE=${C##*=}
        elif [[ "$C" = "color_transfer="* ]]; then
                COLORTRANSFER=${C##*=}
        elif [[ "$C" = "color_primaries="* ]]; then
                COLORPRIMARIES=${C##*=}
        fi      
done    
if [ "${COLORSPACE}" = "bt2020nc" ] && [ "${COLORTRANSFER}" = "smpte2084" ] && [ "${COLORPRIMARIES}" = "bt2020" ]; then 
        echo "$mkv"
		filename=${mkv::-4}
		$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$inputpath/$mkv" -threads 0 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset slow -tune film -crf 17 -maxrate 20029988 -bufsize 40059976 -profile:v:0 high -level 41 -x264opts:0 subme=0:me_range=4:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*3)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=bt709:transfer=bt709:matrix=bt709:tonemap=hable:desat=0:threshold=0.8:peak=100,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags use_metadata_tags "$outputpath/$filename - HDR.mkv"
		exitcode=$?
			if [ $exitcode -ne 0 ]; then
				echo "- Error processing $mkv" >> conversionlog.txt
			fi
fi

done
IFS="$OIFS"
