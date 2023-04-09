#!/bin/bash

# Tonton Jo - 2023
# Join me on Youtube: https://www.youtube.com/c/tontonjo

# This scripts aim to convert all vidéos in MKV format in the best supported one in jellyfin: h264 with AAC Audio 5.1 to avoid transcoding as much as possible
# It will look in $inputpath for content and convert them to x264 SDR to $outputpath

# Prerequisits:
# A working GPU decoding setup in jellyfin if you want to enable GPU and Install needed dependencies to have tonemap and uncomment needed section
# echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list
# apt-get update
# apt-get install aptitude
# aptitude install nvidia-opencl-icd

# Usage:
# Put script in a jellyfin container accessible folder
# Edit the configuration in the script - for more informations about settings: https://trac.ffmpeg.org/wiki/Encode/H.264
# Connect yourself into container
# Run the script 
# The scrit does not (yet, maybe never) support subtitles conversion

# arguments:
# none: automatically process video: hdr and vidéo + audio if needed
# -video		: Only convert video
# -audio		: Only convert audio to specified format
# -r			: Rename video track with the filename
# -smooth		: upgrade vidéo to 60 FPS using tblend
# -force-video	: Automatic mode, but will forcefully convert files already in h264 if their bitrate exeed the wanted bitrate - defined as a ratio betwee actual file bitrate and wanted bitrate

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
# 4.0 - Too many changes sorry again
# 5.0 - add option to leave empty outputpath in order to everwrite the original file when task was successfully done
# 5.1 - echo filesize in human rdbl format
# 5.2 - Fix media conversion of files with unknownk audio channel_laynout as it leads to transcodes from Jellyfin & add option to only process a defined number of entries
# 6.0 - Can now remove unwanted languages
# 6.1 - add check for unwanted language
# 6.2 - fix audio - add cancelation of transcode if dovi is found
# 7.0 - Reworked script for better reading and add option for GPU x264 decoding
# 7.1 - Add option to remove language separatly from audio management, add a ingnore list
# 7.2 - fix nvenc command
# 7.3 - Ignore list now working
# 7.4 - Check if file is in ignore list before anything else. Cleaner and faster
# 7.5 - Remove useless options from GPU trancode tasks - various fixes and corrections
# 7.6 - Already a fix for hdr content - As colors may be faded out without HDR , we will bypass hdr files for now.
# 7.7 - Add -force-video to forcefully re-encode video to reduce file size to a defined bitrate
# 7.8 - simplify bitrate settings - add 2 differente bitrate for 4k and 1080p to allow bigger resolutions video to have bigger bitrates
# 7.9 - Add audio check when processing with -force-video flag
# 8.0 - Add some error management
# 8.1 - Fix resolution detection in some cases
# 8.2 - Fix Process order to ensure every automatic check is done before checking for special flags
# 8.3 - Add bufsize multiplier. cant be lower than 1x the bitrate
# 8.4 - Add detection for Interlaced videos and convert to progressive format - Black magic: conversion has to sometimes be done 2 times - dont ask why.
# 8.5 - Removed encoder level wich is usless and may cause problem for no reasons
# 9.0 - Reworked task definition processing: Better, faster, Stronger - more future proof
# 9.1 - Lots of small changes, try to reduce execution time using smarter positions for the variables definition tasks - removed channel layout check was causing problems somtimes, was there for a reason but dont remember which atm

# ------------- General Settings -------------------------
inputpath="/media/movies"
outputpath=""					# Leave this empty to overwrite the original file when transcode was sucessfull
entries=9999					# number of movies to process - set to a number higher than the number of entries in library to process everything, like 9999999 :-)
ignore=""					# Work in progress - List of file, names or folder to ignore
# ------------- GPU Mode Settings -------------------------
gpuactive=0
# ------------ Quality settings -----------------
bitratefhd=9000000				# Used for ref for -force-video and to encode  - Used as maxrate and doubled for bufsize - typical values: bitrate 10014994 30044982
bitrate4k=15000000				# Used for ref for -force-video and to encode  - Used as maxrate and doubled for bufsize - typical values: bitrate 10014994 30044982
bufsizemultiplier=3				# Bufsize will be set to x times the bitrate set - smaller value means better respect of wanted bitrate, resulting in higher quality loss aswell :)
setsize=30044982 				# File bigger will use crf_bigfile and smaller crf_smallfile
crf_bigfile=20					# Jellyfin recommand value between 18 to 28 - The range of the CRF scale is 0–51, where 0 is lossless - 19 is visually identical to 0
crf_smallfile=18				# Jellyfin recommand value between 18 to 28 - The range of the CRF scale is 0–51, where 0 is lossless - 19 is visually identical to 0
diffratio=1.3					# Files under this ratio wont be converted when using -force-video cause it may be worthless depending on settings
# ------------- Video Settings -------------------------
unwantedcolormap="smpte2084|bt2020nc|bt2020"
unwanted264format="10"
unwanted265format="HEVC"
unwantedvideorange="dovi"
unwantedfieldorder="tt|tb|bb|bt" 	# Thoses identifies Interlaced videos https://ffmpeg.org/ffprobe-all.html
preset=slow 						# Not used in GPU Decoding already set on "p1" - Use the slowest preset that you have patience for: ultrafast,superfastveryfast,faster,fast,medium,slow,veryslow,placebo
subme=9 							# Not used in GPU Decoding -1: Fastest - 2-5: Progressively better - 6-7: 6 is the defaul
me_range=20 						# Not used in GPU Decoding - MErange controls the max range of the motion search - default of 16 - useful on HD footage and for high-motion footage
aqmode=3							# Not used in GPU Decoding
keyframes=1
#------------------- HDR Settings -------------------
threshold=0.8 					# threshold is used to detect whether the scene has changed or not
peak=100 					# Override signal/nominal/reference peak with this value
desat=0		 				# Apply desaturation for highlights that exceed this level of brightness - default of 2.0 - Jelly = 0
# --------------- Audio Settings -------------------
unwantedaudio="dts|ac3|opus|unknown"
neededlanguage="vff"		# https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
unwantedlanguage="vfq"  	# https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes
targetaudioformat="aac"
audiobitrate=320000
# ---------- END OF SETTINGS ---------------------

# ---------------- ENV VARIABLE -----------------------
date=$(date +%Y_%m_%d-%H_%M_%S)
ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg
ffprobe=/usr/lib/jellyfin-ffmpeg/ffprobe
# Allow to handle spaces in "for" loop
OIFS="$IFS"
IFS=$'\n'
# ---------------- ENV VARIABLE -----------------------

# GPU - Convert H265 HDR to X264 with tonemap
hdr() {
$ffmpeg -loglevel quiet -stats -init_hw_device cuda=cu:0 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda -threads 0 \
-i "$mkv" -y \
-map 0:v:0 -codec:v:0 h264_nvenc -pix_fmt yuv420p \
-preset $preset -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "hwupload=derive_device=cuda,tonemap_cuda=format=yuv420p:p=bt709:t=bt709:m=bt709:tonemap=hable:peak=$peak:desat=$desat:threshold=$threshold,hwdownload" \
-avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" \
-f matroska "$outputpath/$outputfile"
}
# GPU - Convert H265 HDR to X264 with tonemap and convert audio to AAC 6 channels
hdraudio() {
$ffmpeg -loglevel quiet -stats -init_hw_device cuda=cu:0 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda -threads 0 \
-i "$mkv" -y \
-map 0:v:0 -codec:v:0 h264_nvenc -pix_fmt yuv420p -threads 0 \
-preset $preset -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "hwupload=derive_device=cuda,tonemap_cuda=format=yuv420p:p=bt709:t=bt709:m=bt709:tonemap=hable:peak=$peak:desat=$desat:threshold=$threshold,hwdownload" \
-avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" \
-f matroska "$outputpath/$outputfile"
}
# CPU - Convert other format to h264
otherformat() {
$ffmpeg -loglevel quiet -stats -i "$mkv" -y -threads 0 \
-map 0:v:0 -codec:v:0 libx264 -pix_fmt yuv420p \
-preset $preset -tune film -crf $crf -aq-mode $aqmode  -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}
# GPU - Convert other format to h264
gpuotherformat() {
$ffmpeg -loglevel quiet -stats -init_hw_device cuda=cu:0 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda -threads 0 \
-i "$mkv" -y \
-map 0:v:0 -codec:v:0 h264_nvenc \
-preset p1 -cq:v $crf -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}
# CPU - Convert other format to h264 and convert audio to AAC 6 channels
otherformataudio() {
$ffmpeg -loglevel quiet -stats -i "$mkv" -y -threads 0 -map 0:v:0 -codec:v:0 libx264 -pix_fmt yuv420p \
-preset $preset -tune film -crf $crf -aq-mode $aqmode  -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}

# GPU - Convert other format to h264 and convert audio to AAC 6 channels
gpuotherformataudio() {
$ffmpeg -loglevel quiet -stats -init_hw_device cuda=cu:0 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda -threads 0 \
-i "$mkv" -y \
-preset p1 -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-map 0:v:0 -codec:v:0 h264_nvenc \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}

# CPU - Convert audio only
audioonly() {
$ffmpeg -stats -i "$mkv"  -y -c:v copy -map 0:v -map 0:a -threads 0 \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -max_muxing_queue_size 9999 \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}
# CPU - Smooth video using minterpolate (fast but not very efficient)
smooth() {
# https://blog.programster.org/ffmpeg-create-smooth-videos-with-frame-interpolation
$ffmpeg -loglevel quiet -stats -field_order progressive -i "$mkv" -y -threads 0 -map 0:v:0 \
-vf "minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1" \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-f matroska "$outputpath/$outputfile"
}
# CPU - Just rename the MKV title metadata using the filename
rename() {
$ffmpeg -loglevel quiet -stats -i "$mkv" -c:v copy -map 0:v -threads 0 \
-c:a copy -map 0:a \
-c:s copy -map 0:s \
-movflags -use_metadata_tags -metadata title="$filename" \
-f matroska "$outputpath/$outputfile"
}
# CPU - alpha: remove unwanted language, 1 at a time
unwanted_language() {
$ffmpeg -loglevel quiet -stats -i "$mkv" -y -threads 0 \
-c:v copy -map 0:v -map 0:a -map -0:a:$removeaudiotrackindex \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -max_muxing_queue_size 9999 \
-c:s copy -map 0:s? \
-f matroska "$outputpath/$outputfile"
}
interlaced() {
			
			echo "- File is interlaced - converting to progressive" >> $inputpath/conversionlog.txt
				if [ "$gpuactive" -eq "0" ]; then
					echo "- Processing interlaced video only using CPU" >> $inputpath/conversionlog.txt
					# Run ffmpeg command otherformataudio
					transcodetask=otherformat
					runtranscode
				else
					echo "- Processing interlaced video video only using GPU" >> $inputpath/conversionlog.txt
					# Run ffmpeg command gpuotherformataudio
					transcodetask=gpuotherformat
					runtranscode
				fi
}

# run the transcode task If no output path is specified, replace the original file on conversion success
runtranscode() {
	filesize=$(ls -l "$mkv" | awk '{print $5}')
	humanrdblfilesize=$(echo "$filesize" | numfmt --to=iec)
	file=$(basename "$mkv")
	filename=${file::-4}
	crfcheck
if [ -z "$outputpath" ]; then
	  echo "- No outputpath specified, file will be overwritten on success" >> $inputpath/conversionlog.txt
      outputpath=$(dirname "$mkv")
	  outputfile="$file.tmp"
	  $transcodetask
	  exitcode=$?
		if [ $exitcode -ne 0 ]; then
			echo "- Error happened while processing - original file not replaced" >> $inputpath/conversionlog.txt
			echo "- Error happened while processing - original file not replaced"
			rm -rf "$outputpath/$file.tmp"
		else
			newfilesize=$(ls -l "$outputpath/$outputfile" | awk '{print $5}')
			humanrdblnewfilesize=$(echo "$newfilesize" | numfmt --to=iec)
			echo "- Convertion ended successfully - overwriting existing file" >> $inputpath/conversionlog.txt
			mv -f "$outputpath/$file.tmp" "$outputpath/$file"
			echo "- Original filesize:  $humanrdblfilesize" >> $inputpath/conversionlog.txt
			echo "- New filesize:		$humanrdblnewfilesize" >> $inputpath/conversionlog.txt
		fi
		
		# unset outputpath in order to redifine $outputpath for every file
		unset outputpath
else
	echo "- Outputpath specified - file will not be overwritten" >> $inputpath/conversionlog.txt
	mkdir -p $outputpath
	outputfile="$file"
    $transcodetask
	exitcode=$?
	if [ $exitcode -ne 0 ]; then
		echo "- Error happened while processing" >> $inputpath/conversionlog.txt
		echo "- Error happened while processing"
		rm -rf "$outputpath/$file"
	else
		newfilesize=$(ls -l "$outputpath/$outputfile" | awk '{print $5}')
		humanrdblnewfilesize=$(echo "$newfilesize" | numfmt --to=iec)
		echo "- Convertion ended successfully" >> $inputpath/conversionlog.txt
		echo "- Original filesize:  $humanrdblfilesize" >> $inputpath/conversionlog.txt
		echo "- New filesize:		$humanrdblnewfilesize" >> $inputpath/conversionlog.txt
	fi
fi
# Dont understand well yet, but interlaced TT files have to be processed 2 times to become "progressive"
if [ "$interlaced" -eq "1" ]; then
	# Update ffprobe output
	ffprobeoutput=$($ffprobe -hide_banner -show_streams "$mkv"  2>&1)
	if echo "$ffprobeoutput" | grep 'field_order' | grep -Eqi "$unwantedfieldorder" ; then
		echo "- File is still not Progressive"
		interlaced
	else
		echo "- File is now Progressive" >> $inputpath/conversionlog.txt
	fi
fi
}

crfcheck() {
			# This is intended to try to avoid big files when converting huge 265 files
			if (( $filesize > $setsize )); then
				echo "- File size is greater than set size use CRF $crf_bigfile" >> $inputpath/conversionlog.txt
				crf=$crf_bigfile
			else
				echo "- File size is smaller than set size use CRF $crf_smallfile" >> $inputpath/conversionlog.txt
				crf=$crf_smallfile
			fi
}

removeunwantedlanguage() {
		# Get title and index, filter to get line abve the unwanted language, remove what's before = then substract 1 as this number ignore the video track
		removeaudiotrackindex=$(echo "$ffprobeoutput" -show_streams "$mkv" | grep -Eiw "index|title" | grep -Eiw -B 1 $unwantedlanguage | grep index | sed 's/^[^=]*=//' | awk '{print $1-1}')
		if [ -z "$removeaudiotrackindex" ]; then
				echo "- No Audio track to remove" >> $inputpath/conversionlog.txt 
		else
			# If there's a track to remove, ensure it contains the $neededlanguage
			if echo "$ffprobeoutput" -show_streams "$mkv" | grep -Eiw "title" | grep -Eiw $neededlanguage; then
				echo "- Removing index $removeaudiotrackindex" >> $inputpath/conversionlog.txt
				transcodetask=unwanted_language
				runtranscode
				else
				echo "- Unwanted format found but VFF not found - aborting" >> $inputpath/conversionlog.txt
			fi

		fi
}

audio() {
		if echo "$ffprobeoutput" | grep -E 'codec|channel_layout' | grep -Eqi "$unwantedaudio" ; then
				echo "- Unwanted format found - converting audio" >> $inputpath/conversionlog.txt 
				transcodetask=audioonly
				runtranscode
		else
				echo "- No conversion needed" >> $inputpath/conversionlog.txt 
		fi
}
if  [[ $1 = "-force-video" ]]; then
	# check if root
	if [[ $(id -u) -ne 0 ]] ; then echo "- Please run as root / sudo" ; exit 1 ; fi
	if [ $(dpkg-query -W -f='${Status}' bc 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
		echo "- bc needed - installing"
		apt-get update -y -qq
		apt-get install -y bc;
	fi
fi

# ------------- Start processing files
echo "----- Tonton Jo - 2022 -------"
echo "- Starting conversion of .mkv in $inputpath" >> $inputpath/conversionlog.txt

for mkv in `find $inputpath | grep .mkv | sort -h | head -n $entries`; do
	echo "$mkv" >> $inputpath/conversionlog.txt
	echo "- Processing $mkv"
	# Checking if file is in ignore list
	if echo "$mkv" | grep -Eqwi "$ignore" ; then
			echo "- File is in ignore list $ignore" >> $inputpath/conversionlog.txt
			continue
	fi
	ffprobeoutput=$($ffprobe -hide_banner -show_streams "$mkv"  2>&1)
	# If resolution is smaller than 1920 use bitratefhd else use 4k
	resolution=$($ffprobe -hide_banner -v quiet -select_streams v:0 -show_entries stream=width -of default=nw=1:nk=1 "$mkv" 2>&1)
	if (( $(echo "$resolution > 1920") )); then
		echo "- Video is bigger than full HD - using $bitrate4k bps bitrate" >> $inputpath/conversionlog.txt
		bitrate="$bitrate4k"
	else
		echo "- Video is equal or smaller than full HD - using $bitratefhd bps bitrate" >> $inputpath/conversionlog.txt
		bitrate="$bitratefhd"
	fi
	filebitrate=$(echo "$ffprobeoutput" | grep "Duration" | awk '{print $6 * 1000}')
	# Set maxrate and bufsize
	maxrate="$bitrate"
	bufsize=$(($bitrate * $bufsizemultiplier))
	
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedvideorange" ; then
		echo "- Found unwanted video range ($unwantedvideorange) that cannot be converted atm - continuing" >> $inputpath/conversionlog.txt
		continue
	fi

	# Define if audio needs to be converted
	if echo "$ffprobeoutput" | grep 'codec_name' | grep -Eqi "$unwantedaudio" ; then
		echo "- File contains unwanted Audio format" >> $inputpath/conversionlog.txt
		audioscore=1
	else
		audioscore=0
	fi
	
	if  echo "$ffprobeoutput" | grep codec_name | grep -qi "$unwanted265format" ; then
		echo "- Files is H265" >> $inputpath/conversionlog.txt
		videoscore=10
		if echo "$ffprobeoutput" | grep -Eqi "$unwantedcolormap" ; then
			echo "- Files is HDR" >> $inputpath/conversionlog.txt
			hdrscore=20
		else
			hdrscore=0
		fi
	elif  echo "$ffprobeoutput" | grep profile | grep -Eqi "$unwanted264format" ; then
			echo "- Files is 10bit" >> $inputpath/conversionlog.txt
			videoscore=10
	fi

	if echo "$ffprobeoutput" | grep 'field_order' | grep -Eqi "$unwantedfieldorder" ; then
		echo "- Files is interlaced" >> $inputpath/conversionlog.txt
		interlaced=1
	else
		interlaced=0
	fi
	if  [[ $1 = "-force-video" ]]; then
		filebitrateratio=$(echo "scale=2; $filebitrate / $bitrate" | bc)
		if (( $(echo "$filebitrateratio > $diffratio" | bc -l) )); then
			echo "- File bitrate is above wanted bitrate" >> $inputpath/conversionlog.txt
			videoscore=10
		fi
	fi
	if [ -z "$videoscore" ]; then
	videoscore=0
	fi
	
	conversionscore=$(($videoscore + $hdrscore + $audioscore))
	
	# ------------- Start processing based on flags
	if  [[ $1 = "-smooth" ]]; then 
		# raise framerate of input to 60 fps
		echo "- Smoothing video to 60 FPS" >> $inputpath/conversionlog.txt
		transcodetask=smooth
	elif  [[ $1 = "-removeunwantedlanguage" ]]; then 
		# remove $unwantedlanguage
		echo "- Removing $unwantedlanguage" >> $inputpath/conversionlog.txt
		transcodetask=removeunwantedlanguage
	elif  [[ $1 = "-audio" ]]; then
		# Transcode Audio only
		transcodetask=audioonly
	elif  [[ $1 = "-video" ]]; then 
		# Transcode Video only
		echo "- Converting Video to h264 8 bits" >> $inputpath/conversionlog.txt
		transcodetask=gpuotherformat
	elif  [[ $1 = "-rename" ]]; then 
		# Rename video track
		echo "- Renaming video track with $filename" >> $inputpath/conversionlog.txt
		transcodetask=rename
	# ------------- Start processing based on video score defined above
	# above 30 means audio and hdr content
	elif [ "$conversionscore" -gt "30" ]; then
		echo "- Video score: $conversionscore - transcode task: hdraudio" >> $inputpath/conversionlog.txt
		transcodetask=hdraudio
	# above 20 means HDR content
	elif [ "$conversionscore" -eq "30" ]; then
		echo "- Video score: $conversionscore - transcode task: hdr" >> $inputpath/conversionlog.txt
		transcodetask=hdr
	# above 10 means Audio + Video
	elif [ "$conversionscore" -gt "10" ]; then
		echo "- Video score: $conversionscore - transcode task: otherformataudio" >> $inputpath/conversionlog.txt
		if [ "$gpuactive" -eq "0" ]; then
			transcodetask=otherformataudio
		else
			transcodetask=gpuotherformataudio
		fi
	#  equal to 10 means video only				
	elif [ "$conversionscore" -eq "10" ]; then
		echo "- Video score: $conversionscore - transcode task: otherformat" >> $inputpath/conversionlog.txt
		if [ "$gpuactive" -eq "0" ]; then
			transcodetask=otherformat
		else
			transcodetask=gpuotherformat
		fi
	# equal to 1 means Audio only		
	elif [ "$conversionscore" -eq "1" ]; then
			echo "- Video score: $conversionscore - transcode task: audioonly" >> $inputpath/conversionlog.txt
			transcodetask=audioonly
	else
		# if none of the above was needed - continue
		continue
	fi
	runtranscode
	unset audioscore
	unset hdrscore
	unset videoscore
done
echo "Conversion ended!" >> $inputpath/conversionlog.txt
IFS="$OIFS"
