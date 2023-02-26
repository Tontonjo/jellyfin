#!/bin/bash

# Tonton Jo - 2023
# Join me on Youtube: https://www.youtube.com/c/tontonjo

# This scripts aim to convert all vidéos in MKV format in the best supported one in jellyfin: h264 with AAC Audio to avoid transcoding
# It will look in $inputpath for content and convert them to x264 SDR to $outputpath

# Prerequisits:
# A working GPU decoding setup in jellyfin if you want to enable GPU
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
# none: automatically process video: hdr and vidéo + audio if needed
# -video	: Only convert video
# -audio	: Only convert audio to specified format
# -r		: Rename video track with the filename
# -smooth	: upgrade vidéo to 60 FPS using tblend

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

# ------------- General Settings -------------------------
inputpath="/media/movies"
outputpath=""			# Leave this empty to overwrite the original file when transcode was sucessfull
entries=9999			# number of movies to process - set to a number higher than the number of entries in library to process everything, like 9999999 :-)
ignore=""	# Work in progress - List of file, names or folder to ignore
# ------------- GPU Mode Settings -------------------------
gpuactive=1
# ------------- Video Settings -------------------------
unwantedcolormap="smpte2084|bt2020nc|bt2020"
unwanted264format="10"
unwanted265format="HEVC"
unwantedvideorange="dovi"
preset=slow 						# Not used in GPU Decoding already set on "p1" - Use the slowest preset that you have patience for: ultrafast,superfastveryfast,faster,fast,medium,slow,veryslow,placebo
tune=film  						# Not used in GPU Decoding - film,animation,grain,stillimage,fastdecode,zerolatency
subme=9 						# Not used in GPU Decoding -1: Fastest - 2-5: Progressively better - 6-7: 6 is the defaul
me_range=20 						# Not used in GPU Decoding - MErange controls the max range of the motion search - default of 16 - useful on HD footage and for high-motion footage
aqmode=3						# Not used in GPU Decoding
keyframes=1
# ------------ CRF Mode -----------------
bitrate=15022491				# typical values: bitrate 10014994 30044982 - maxrate 10014994 - bufsize 5007497
maxrate=15022491 				# Default: 30044982
bufsize=40059976				# Default: 40059976 / 2x bitrate
setsize=30044982 				# File bigger will use crf_bigfile and smaller crf_smallfile
crf_bigfile=24					# Not used in GPU Decoding - The range of the CRF scale is 0–51, where 0 is lossless
crf_smallfile=22				# Not used in GPU Decoding - The range of the CRF scale is 0–51, where 0 is lossless
#------------------- HDR Settings -------------------
threshold=0.8 					# threshold is used to detect whether the scene has changed or not
peak=100 					# Override signal/nominal/reference peak with this value
desat=2.0 					# Apply desaturation for highlights that exceed this level of brightness - default of 2.0 - Jelly = 0
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
$ffmpeg -init_hw_device cuda=cu:0 \
-filter_hw_device cu -hwaccel nvdec -hwaccel_output_format cuda \
-i "$mkv" -y -threads 0 \
-map 0:v:0 -codec:v:0 libx264 -pix_fmt yuv420p \
-preset p1 -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -level 51 -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "hwupload=derive_device=cuda,tonemap_cuda=format=yuv420p:p=bt709:t=bt709:m=bt709:tonemap=hable:peak=$peak:desat=$desat:threshold=$threshold,hwdownload"  -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" \
-f matroska "$outputpath/$outputfile"
}
# GPU - Convert H265 HDR to X264 with tonemap and convert audio to AAC 6 channels
hdraudio() {
$ffmpeg -init_hw_device cuda=cu:0 \
 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda \
 -i "$mkv" -y -threads 0 \
 -map 0:v:0 -codec:v:0 libx264 -pix_fmt yuv420p \
 -preset p1 -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
 -profile:v:0 high -level 51 -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
 -vf "hwupload=derive_device=cuda,tonemap_cuda=format=yuv420p:p=bt709:t=bt709:m=bt709:tonemap=hable:peak=$peak:desat=$desat:threshold=$threshold,hwdownload" \
 -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
 -c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a \
 -c:s copy -map 0:s? \
 -movflags -use_metadata_tags -metadata title="$filename - HDR tonemap script from youtube.com/tontonjo" -metadata:s:v:0 title="Tonemaped" \
 -f matroska "$outputpath/$outputfile"
}
# CPU - Convert other format to h264
otherformat() {
$ffmpeg -i "$mkv" -y -threads 0 \
-map 0:v:0 -codec:v:0 libx264 -pix_fmt yuv420p \
-preset $preset -tune $tune -crf $crf -aq-mode $aqmode  -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -level 51 -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}
# GPU - Convert other format to h264
gpuotherformat() {
$ffmpeg -init_hw_device cuda=cu:0 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda -threads 1 \
-i "$mkv" -y \
-map 0:v:0 -codec:v:0 h264_nvenc \
-preset p1 -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -level 51 -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709,scale_cuda=format=yuv420p" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}
# CPU - Convert other format to h264 and convert audio to AAC 6 channels
otherformataudio() {
$ffmpeg -i "$mkv" -y -threads 0 -map 0:v:0 -codec:v:0 libx264 -pix_fmt yuv420p \
-preset $preset -tune $tune -crf $crf -aq-mode $aqmode  -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -level 51 -x264opts:0 subme=$subme:me_range=$merange:rc_lookahead=10:me=dia:no_chroma_me:8x8dct=0:partitions=none  -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}

# GPU - Convert other format to h264 and convert audio to AAC 6 channels
gpuotherformataudio() {
$ffmpeg -init_hw_device cuda=cu:0 -filter_hw_device cu -hwaccel cuda -hwaccel_output_format cuda -threads 1 \
-i "$mkv" -y \
-map 0:v:0 -codec:v:0 h264_nvenc \
-preset p1 -b:v $bitrate -maxrate $maxrate -bufsize $bufsize \
-profile:v:0 high -level 51 -force_key_frames:0 "expr:gte(t,0+n_forced*$keyframes)" \
-vf "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709,scale_cuda=format=yuv420p" -avoid_negative_ts disabled -max_muxing_queue_size 9999 \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -map 0:a \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}

# CPU - Convert audio only
audioonly() {
$ffmpeg -i "$mkv"  -y -c:v copy -map 0:v -map 0:a \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -max_muxing_queue_size 9999 \
-c:s copy -map 0:s? \
-movflags -use_metadata_tags -metadata title="$filename - Conversion script from youtube.com/tontonjo" -metadata:s:v:0 title=" " \
-f matroska "$outputpath/$outputfile"
}
# CPU - Smooth video using minterpolate (fast but not very efficient)
smooth() {
# https://blog.programster.org/ffmpeg-create-smooth-videos-with-frame-interpolation
$ffmpeg -i "$mkv" -y -threads 0 -map 0:v:0 \
-vf "minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1" \
-c:a copy -map 0:a \
-c:s copy -map 0:s? \
-f matroska "$outputpath/$outputfile"
}
# CPU - Just rename the MKV title metadata using the filename
rename() {
$ffmpeg -i "$mkv" -c:v copy -map 0:v \
-c:a copy -map 0:a \
-c:s copy -map 0:s \
-movflags -use_metadata_tags -metadata title="$filename" \
-f matroska "$outputpath/$outputfile"
}
# CPU - alpha: remove unwanted language, 1 at a time
unwanted_language() {
$ffmpeg -i "$mkv" -y -c:v copy -map 0:v -map 0:a -map -0:a:$removeaudiotrackindex \
-c:a $targetaudioformat -ac 6 -ab $audiobitrate -max_muxing_queue_size 9999 \
-c:s copy -map 0:s? \
-f matroska "$outputpath/$outputfile"
}


# run the transcode task If no output path is specified, replace the original file on conversion success
runtranscode() {
if [ -z "$outputpath" ]; then
	  echo "- No outputpath specified, file will be overwritten on success" >> $inputpath/conversionlog.txt
      outputpath=$(dirname "$mkv")
	  outputfile="$file.tmp"
	  $transcodetask
	  exitcode=$?
		if [ $exitcode -ne 0 ]; then
			echo "- Error happened while processing - original file not replaced" >> $inputpath/conversionlog.txt
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
		rm -rf "$outputpath/$file"
	else
		newfilesize=$(ls -l "$outputpath/$outputfile" | awk '{print $5}')
		humanrdblnewfilesize=$(echo "$newfilesize" | numfmt --to=iec)
		echo "- Convertion ended successfully" >> $inputpath/conversionlog.txt
		echo "- Original filesize:  $humanrdblfilesize" >> $inputpath/conversionlog.txt
		echo "- New filesize:		$humanrdblnewfilesize" >> $inputpath/conversionlog.txt
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

echo "----- Tonton Jo - 2022 -----" > $inputpath/conversionlog.txt
echo "------- Job of $date -------" >> $inputpath/conversionlog.txt
echo "- Starting conversion of .mkv in $inputpath" >> $inputpath/conversionlog.txt


# Check if option has been passed, if none, run in default mode and look for HDR content in $inputpath - if fail, fallback to non-tonemaped encoder or check if h264 10 bits
for mkv in `find $inputpath | grep .mkv | sort -h | head -n $entries`; do
	echo "$mkv" >> $inputpath/conversionlog.txt
	# Checking if file is in ignore list
	if [ -z "$ignore" ]; then
		echo "- No ignored files configured" >> $inputpath/conversionlog.txt
	else
		if echo "$mkv" | grep -Ewi "$ignore" ; then
			echo "- File is in ignore list $ignore" >> $inputpath/conversionlog.txt
			continue
		else
			echo "- File is not in ignore list $ignore" >> $inputpath/conversionlog.txt
		fi
	fi
	filesize=$(ls -l "$mkv" | awk '{print $5}')
	humanrdblfilesize=$(echo "$filesize" | numfmt --to=iec)
	file=$(basename "$mkv")
	filename=${file::-4}
	ffprobeoutput=$($ffprobe -show_streams "$mkv")
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedvideorange" ; then
		echo "$mkv - Found unwanted video range ($unwantedvideorange) that cannot be converted atm - continuing" >> $inputpath/checklog.txt
		continue
	elif  [[ $1 = "-smooth" ]]; then 
		# raise framerate of input to 60 fps
		echo "- Smoothing video to 60 FPS" >> $inputpath/conversionlog.txt
		transcodetask=smooth
		runtranscode
	elif  [[ $1 = "-removeunwantedlanguage" ]]; then 
		# remove $unwantedlanguage
		echo "- Removing $unwantedlanguage" >> $inputpath/conversionlog.txt
		transcodetask=removeunwantedlanguage
		runtranscode
	elif  [[ $1 = "-audio" ]]; then
		# Transcode Audio only
		audio
	elif  [[ $1 = "-video" ]]; then 
		# Transcode Video only
		echo "- Converting Video to h264 8 bits" >> $inputpath/conversionlog.txt
		transcodetask=gpuotherformat
		crfcheck
		runtranscode
	elif  [[ $1 = "-rename" ]]; then 
		# Rename video track
		echo "- Renaming video track with $filename" >> $inputpath/conversionlog.txt
		transcodetask=rename
		runtranscode
		
	# If no option set - entering auto mode: check HDR: if fail try to normal transcode - if audio is equal to $unwantedaudio - transcode audio aswell
	#
	#	crfcheck
	#	if echo "$ffprobeoutput" | grep 'codec\|channel_layout' | grep -Eqi "$unwantedaudio" ; then
	#		echo "- Processing HDR video + audio" >> $inputpath/conversionlog.txt
			# Run ffmpeg command hdraudio
	#		transcodetask=hdraudio
	#		runtranscode
			# If fail try to use no tonmap command
			#if [ $exitcode -ne 0 ]; then
			#	echo "- Trying no tonemaped command" >> $inputpath/conversionlog.txt
			#	transcodetask=otherformataudio
			#	runtranscode
			#fi
	#	else
	#		echo "- Processing HDR video only" >> $inputpath/conversionlog.txt
			# Run ffmpeg command hdr
	#		transcodetask=hdr
	#		runtranscode
			# If fail try to use no tonmap command
			#if [ $exitcode -ne 0 ]; then
			#	echo "- Error happened while processing - tying no tonemaped command" >> $inputpath/conversionlog.txt
			#	transcodetask=otherformat
			#	runtranscode
			#fi
	#	fi
	# If no HDR found, check for H265
	elif  echo "$ffprobeoutput" | grep codec_name | grep -qi "$unwanted265format" ; then
		echo "- File is H265 " >> $inputpath/conversionlog.txt
		crfcheck
		if echo "$ffprobeoutput" | grep -E 'codec|channel_layout' | grep -Eqi "$unwantedaudio" ; then
			if [ "$gpuactive" -eq "0" ]; then
				echo "- Processing H265 video + audio using CPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command otherformataudio
				transcodetask=otherformataudio
				runtranscode
			else
				echo "- Processing H265 video + audio using GPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command gpuotherformataudio
				transcodetask=gpuotherformataudio
				runtranscode
			fi
		else
			if [ "$gpuactive" -eq "0" ]; then
				echo "- Processing H265 video only using CPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command otherformataudio
				transcodetask=otherformat
				runtranscode
			else
				echo "- Processing H265 video only using GPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command gpuotherformat
				transcodetask=gpuotherformat
				runtranscode
			fi
		fi
	# Check if profile is 10 bits - placed after HEVC detection to better know if it matches HEVC or H264 10 bits as HEVC 10 bits would match this aswell but may lose HDR infos
	elif  echo "$ffprobeoutput" | grep profile | grep -Eqi "$unwanted264format" ; then
		echo "- File is H264 10 bits" >> $inputpath/conversionlog.txt
		crfcheck
		if echo "$ffprobeoutput" | grep 'codec\|channel_layout' | grep -Eqi "$unwantedaudio" ; then
			if [ "$gpuactive" -eq "0" ]; then
				echo "- Processing 10 bits video + audio using CPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command otherformataudio
				transcodetask=otherformataudio
				runtranscode
			else
				echo "- Processing 10 bits video + audio using GPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command gpuotherformataudio
				transcodetask=gpuotherformataudio
				runtranscode
			fi
		else
			if [ "$gpuactive" -eq "0" ]; then
				echo "- Processing 10 bits video only using CPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command otherformataudio
				transcodetask=otherformat
				runtranscode
			else
				echo "- Processing 10 bits video video only using GPU" >> $inputpath/conversionlog.txt
				# Run ffmpeg command gpuotherformataudio
				transcodetask=gpuotherformat
				runtranscode
			fi
		fi
	else
		if echo "$ffprobeoutput" | grep 'codec\|channel_layout' | grep -Eqi "$unwantedaudio" ; then
			echo "- Processing audio only" >> $inputpath/conversionlog.txt
			# Run ffmpeg command audioonly
			transcodetask=audioonly
			runtranscode
		else
			echo "- No conversion needed" >> $inputpath/conversionlog.txt
		fi

	fi
	done
echo "Conversion ended!" >> $inputpath/conversionlog.txt
IFS="$OIFS"
