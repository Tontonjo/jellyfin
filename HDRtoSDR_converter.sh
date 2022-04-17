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
# arguments:
# none: only video
# -all: process vidéo + audio if needed
# -r: rename video track with the filename
# -smooth: upgrade vidéo to 60 FPS using tblend

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
# 3.0 - Too many changes sorry - now can transcode audio dts-ac3 to aac 5.1

# ------------- Settings -------------------------
inputpath=/media/unmanic/converter
outputpath=/media/unmanic
unwantedcolormap="smpte2084|bt2020nc|bt2020"
preset=slower 					# Use the slowest preset that you have patience for: ultrafast,superfastveryfast,faster,fast,medium,slow,slower,veryslow,placebo
tune=film  					# film,animation,grain,stillimage,fastdecode,zerolatency
subme=6 					#1: Fastest - 2-5: Progressively better - 6-7: 6 is the defaul
me_range=20 					# MErange controls the max range of the motion search - default of 16 - useful on HD footage and for high-motion footage
aqmode=3
# ------------ CRF Mode -----------------
bitrate=20029988				# typical values: bitrate 10014994 - maxrate 10014994 - bufsize 5007497
maxrate=20029988 
bufsize=40059976
setsize=15000000000 				# File bigger will use crf_bigfile and smaller crf_smallfile
crf_bigfile=23					# The range of the CRF scale is 0–51, where 0 is lossless
crf_smallfile=20				# The range of the CRF scale is 0–51, where 0 is lossless
#------------------- HDR Settings -------------------
threshold=0.8 					# threshold is used to detect whether the scene has changed or not
peak=100 					# Override signal/nominal/reference peak with this value
desat=2.0 					# Apply desaturation for highlights that exceed this level of brightness - default of 2.0 - Jelly = 0
# --------------- Audio Settings -------------------
unwantedaudio="dts|ac3"
targetaudioformat=aac
audiobitrate=640000
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


# Check if option has been passed, if none, run in default mode and lookd for HDR content in $inputpath
if [ $# -eq 0 ]; then
	echo "- No specific video specified - recusing in $inputpath"
	for mkv in `find $inputpath | grep .mkv`
	do
	# Set variables to use
	filesize=$(ls -l "$mkv" | awk '{print $5}')
	file=$(basename "$mkv")
	filename=${file::-4}
	ffprobeoutput=$($ffprobe -show_streams $mkv)
	echo "Processing $mkv" >> $outputpath/conversionlog.txt
	# If bitrate settings is not set, determine bitrate to try to match the original file bitrate
		"- Determining CRF to use" >> $outputpath/conversionlog.txt
		if [$filesize -gt $setsize]; then
			echo "- File size is greater than set size use CRF $crf_bigfile" >> $outputpath/conversionlog.txt
			crf=$crf_bigfile
		else
			echo "- File size is smaller than set size use CRF $crf_smallfile" >> $outputpath/conversionlog.txt
			crf=$crf_smallfile
		fi
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedcolormap" ; then
		echo "- Processing video only" >> $outputpath/conversionlog.txt
			if echo "$ffprobeoutput" | grep color_primaries=bt2020; then
				echo "- Video is using bt2020 colormap" >> $outputpath/conversionlog.txt
				colorprimaries=bt2020
			else
				echo "- Video is using bt709 colormap" >> $outputpath/conversionlog.txt
				colorprimaries=bt709
			fi
		$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -y -threads 0 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 41 -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*2)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=$colorprimaries:transfer=$colorprimaries:matrix=$colorprimaries:tonemap=hable:desat=$desat:threshold=$threshold:peak=$peak,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" "$outputpath/$filename.mkv"
		exitcode=$?
			if [ $exitcode -ne 0 ]; then
				echo "- Error processing $mkv" >> $outputpath/conversionlog.txt
			fi
	fi
	done


# If -all set convert video + audio
elif  [[ $1 = "-all" ]]; then
	for mkv in `find $inputpath | grep .mkv`
	do
	echo "Processing $mkv" >> $outputpath/conversionlog.txt
	filesize=$(ls -l "$mkv" | awk '{print $5}')
	file=$(basename "$mkv")
	filename=${file::-4}
	ffprobeoutput=$($ffprobe -show_streams $mkv)
			echo "- Determining CRF to use" >> $outputpath/conversionlog.txt
			# If a bitrate is set use default CRF and bitrate values
			if (( $filesize > $setsize )); then
				echo "- File size is greater than set size use CRF $crf_bigfile" >> $outputpath/conversionlog.txt
				crf=$crf_bigfile
			else
				echo "- File size is smaller than set size use CRF $crf_smallfile" >> $outputpath/conversionlog.txt
				crf=$crf_smallfile
			fi
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedcolormap" ; then
		if echo "$ffprobeoutput" | grep color_primaries=bt2020; then
				echo "- Video is using bt2020 colormap" >> $outputpath/conversionlog.txt
				colorprimaries=bt2020
		else
				echo "- Video is using bt709 colormap" >> $outputpath/conversionlog.txt
				colorprimaries=bt709
		fi
		if echo "$ffprobeoutput" | grep codec | grep -Eqi "$unwantedaudio" ; then
			echo "- Processing video + audio" >> $outputpath/conversionlog.txt
			$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -y -threads 0 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -aq-mode $aqmode -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 51 -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*2)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=$colorprimaries:transfer=$colorprimaries:matrix=$colorprimaries:tonemap=hable:desat=$desat:threshold=$threshold:peak=$peak,hwdownload,format=nv12" -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" "$outputpath/$filename.mkv"
		else
				echo "- Processing video only" >> $outputpath/conversionlog.txt
				$ffmpeg -c:v hevc_cuvid -init_hw_device opencl=ocl:0.0 -filter_hw_device ocl -i "$mkv" -y -threads 0 -map 0:0 -codec:v:0 libx264 -pix_fmt yuv420p -preset $preset -tune $tune -crf $crf -aq-mode $aqmode -b:v $bitrate -maxrate $maxrate -bufsize $bufsize -profile:v:0 high -level 51 -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*2)" -vf "hwupload,tonemap_opencl=format=nv12:primaries=$colorprimaries:transfer=$colorprimaries:matrix=$colorprimaries:tonemap=hable:desat=$desat:threshold=$threshold:peak=$peak,hwdownload,format=nv12"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 -c:a copy -map 0:a -c:s copy -map 0:s -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" "$outputpath/$filename.mkv"
		fi
	else
		if echo "$ffprobeoutput" | grep codec | grep -Eqi "$unwantedaudio" ; then
			echo "- Processing audio only" >> $outputpath/conversionlog.txt
			$ffmpeg -i "$mkv" -y -c:v copy -map 0:v -c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a -c:s copy -map 0:s "$outputpath/$filename.mkv"
		else
		echo "- No audio conversion needed" >> $outputpath/conversionlog.txt
		fi
	fi
	done
elif  [[ $1 = "-smooth" ]]; then 
	for mkv in `find $inputpath | grep .mkv`
	do
	file=$(basename "$mkv")
	filename=${file::-4}
	# raise framerate of input to 60 fps
	$ffmpeg -i "$mkv" -y -threads 0 -c:a copy -map 0:a -c:s copy -map 0:s -filter:v "tblend" -r 60 "$outputpath/$filename.mkv"
	done
else
	echo "- Wrong parameter"
fi
IFS="$OIFS"
