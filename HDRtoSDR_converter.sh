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
# HDR tonemap: all credits to Jellyfin https://github.com/jellyfin/jellyfin
# https://trac.ffmpeg.org/wiki/Limiting%20the%20output%20bitrate
# https://unix.stackexchange.com/questions/9496/looping-through-files-with-spaces-in-the-names
# https://video.stackexchange.com/questions/22059/how-to-identify-hdr-video
# https://github.com/jellyfin/jellyfin/pull/3442#issuecomment-700368424

# The base of this script was written and tested live on twitch - twitch.com/tonton_jo

# Version:
# 1.0 - Lots of imprvements after initial twitch version
# 2.0 - Add option to rename the title according to the file name (usefull when it contains unwanted infos ^^) - execute in target folder
# 2.1 - Simplifiy detection of hdr files
# 2.2 - Process files alphabetically

# ------------- Settings -------------------------
inputpath=/media/films
outputpath=/media/output
crf=22 # The range of the CRF scale is 0–51, where 0 is lossless
preset=slower # Use the slowest preset that you have patience for: ultrafast,superfastveryfast,faster,fast,medium,slow,slower,veryslow,placebo
tune=film  # film,animation,grain,stillimage,fastdecode,zerolatency
bitrate=20029988 # The typical example would be something like this: bitrate 10014994 - maxrate 10014994 - bufsize 5007497
maxrate=20029988
bufsize=40059976
# ---------- END OF SETTINGS ---------------------

# ---------------- ENV VARIABLE -----------------------
ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg
ffprobe=/usr/lib/jellyfin-ffmpeg/ffprobe
unwantedcolormap="smpte2084|bt2020nc|bt2020"
# Allow to handle spaces in "for" loop
OIFS="$IFS"
IFS=$'\n'
# ---------------- ENV VARIABLE -----------------------

echo "----- Tonton Jo - 2022 -----" > $outputpath/conversionlog.txt
echo "- Starting conversion of .mkv in $inputpath" >> $outputpath/conversionlog.txt

# Check if option has been passed, if none, run in default mode and lookd for HDR content in $inputpath
if [ $# -eq 0 ]; then
	echo "- No specific video specified - recusing in $inputpath"
	for mkv in `find $inputpath | sort -h | grep .mkv`
	do
	file=$(basename "$mkv")
	filename=${file::-4}
	echo "- Processing $mkv" >> $outputpath/conversionlog.txt
	echo "- Processing $mkv"
	if $ffprobe -show_streams $mkv | grep -Ewqi "$unwantedcolormap" ; then
	$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -threads 0 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 41 -x264opts:0 subme=0:me_range=4:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*3)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=bt709:transfer=bt709:matrix=bt709:tonemap=hable:desat=0:threshold=0.8:peak=100,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" "$outputpath/$filename - HDR.mkv"
	exitcode=$?
		if [ $exitcode -ne 0 ]; then
			echo "- Error processing $mkv" >> $outputpath/conversionlog.txt
		fi
	fi
	done
# If -r option is set, set the actual file name as Title in movie tag
elif  [[ $1 = "-r" ]]; then
	for mkv in `find $inputpath | sort -h | grep .mkv`
	do
	file=$(basename "$mkv")
	filename=${file::-4}
	$ffmpeg -i "$mkv" -c:v copy -map 0:v -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" "$outputpath/$filename.mkv"
	done
else
		mkv=$@
		file=$(basename "$mkv")
		filename=${file::-4}
		echo "- Processing $mkv" > $outputpath/conversionlog.txt
		echo "- Processing $mkv"
		if $ffprobe -show_streams $mkv | grep -Ewqi "$unwantedcolormap" ; then
		$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -threads 0 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 41 -x264opts:0 subme=0:me_range=4:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*3)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=bt709:transfer=bt709:matrix=bt709:tonemap=hable:desat=0:threshold=0.8:peak=100,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" "$outputpath/$filename - HDR.mkv"
		exitcode=$?
		if [ $exitcode -ne 0 ]; then
				echo "- Error processing $mkv" >> $outputpath/conversionlog.txt
		fi
		else 
		echo "- File does not looks to have any HDR colors" && echo "- File does not looks to have any HDR colors" >> $outputpath/conversionlog.txt	
		fi
		exitcode=$?
fi
IFS="$OIFS"
