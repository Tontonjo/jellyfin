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
# Edit the configuration in the script - for more informations about settings: https://trac.ffmpeg.org/wiki/Encode/H.264
# make it executable "docker exec jellyfin chmod +x /media/HDRtoSDR_converter.sh"
# run it executable "docker exec jellyfin /media/HDRtoSDR_converter.sh"

# Sources: 
# https://unix.stackexchange.com/questions/9496/looping-through-files-with-spaces-in-the-names
# https://video.stackexchange.com/questions/22059/how-to-identify-hdr-video
# https://github.com/jellyfin/jellyfin/pull/3442#issuecomment-700368424

# The base of this script was written and tested live on twitch - twitch.com/tonton_jo

# Version:
# 1.0 - Lots of imprvements after initial twitch version

# ------------- Settings -------------------------
inputpath=/media/films
outputpath=/media/output
crf=17 # The range of the CRF scale is 0–51, where 0 is lossless
preset=slower # Use the slowest preset that you have patience for: ultrafast,superfastveryfast,faster,fast,medium,slow,slower,veryslow,placebo
tune=film  # film,animation,grain,stillimage,fastdecode,zerolatency
bitrate=10014994 # Target bitrate in bps
maxrate=10014994 # Target bitrate in bps
bufsize=10014994
# ---------- END OF SETTINGS ---------------------

# ---------------- ENV VARIABLE -----------------------
ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg
ffprobe=/usr/lib/jellyfin-ffmpeg/ffprobe
# Allow to handle spaces in "for" loop
OIFS="$IFS"
IFS=$'\n'
# ---------------- ENV VARIABLE -----------------------

echo "----- Tonton Jo - 2022 -----" > $outputpath/conversionlog.txt
echo "- Starting conversion of .mkv in $inputpath" >> $outputpath/conversionlog.txt
if [ $# -eq 0 ]; then
	echo "- No specific video specified - recusing in $inputpath"
	for mkv in `find $inputpath | grep .mkv`
	do
	file=$(basename "$mkv")
	echo "- Processing $mkv" >> $outputpath/conversionlog.txt
	echo "- Processing $mkv"
	COLORS=$($ffprobe -show_streams -v error "$mkv" |egrep "^color_transfer|^color_space=|^color_primaries=" |head -3)
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
		echo "- - Found HDR file $mkv"
			echo "- - Found HDR file $mkv" >> $outputpath/conversionlog.txt
			filename=${file::-4}
			$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -threads 1 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 41 -x264opts:0 subme=0:me_range=4:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*3)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=bt709:transfer=bt709:matrix=bt709:tonemap=hable:desat=0:threshold=0.8:peak=100,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags  -metadata title="$filename - HDR tonemaped by youtube.com/tontonjo" "$outputpath/$filename - HDR.mkv"
			exitcode=$?
				if [ $exitcode -ne 0 ]; then
					echo "- Error processing $mkv" >> $outputpath/conversionlog.txt
				fi
	fi

	done
else
		mkv=$@
		file=$(basename "$mkv")
		filename=${file::-4}
		echo "- Processing $mkv" >> $outputpath/conversionlog.txt
		echo "- Processing $mkv"
		$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -threads 1 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 41 -x264opts:0 subme=0:me_range=4:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*3)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=bt709:transfer=bt709:matrix=bt709:tonemap=hable:desat=0:threshold=0.8:peak=100,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags  -metadata title="$filename - HDR tonemaped by youtube.com/tontonjo" "$outputpath/$filename - HDR.mkv"
		exitcode=$?
		if [ $exitcode -ne 0 ]; then
		echo "- Error processing $mkv" >> $outputpath/conversionlog.txt			
		fi
fi
IFS="$OIFS"
