#!/bin/bash

# Tonton Jo - 2021
# Join me on Youtube: https://www.youtube.com/c/tontonjo

# This scripts aims to check for every unwanted format / codec in .mkv files
# My goal is to get rid of any partially uncompatible file in order to have no transcode needed.

# Prerequisits:
# ffprobe installed - already in jellyfin container

# Usage:
# Put script in a jellyfin container accessible folder
# Edit the configuration in the script, epecially target path
# run it from container and check "checklog.txt"

# Version:
# 1.0 - Initial release
# 1.1 - Sort alphabetically 
# 1.2 - correction to use ffmpeg echo and ensure grep is for codecs
# 2.0 - added dovi unsupported format wich may cause ffmpeg to hang
# 2.1 - Add check for progressive files
# 2.2 - less noisy output :)

# ------------- Settings -------------------------
inputpath=/media/films
unwantedsub="pgs"
forcedsub="forces|foreced"
unwantedvideorange="dovi"
unwanted265format="HEVC"
unwanted264format="10"
unwantedaudio="dts|ac3"
unwantedcolormap="smpte2084|bt2020nc|bt2020"
unwantedfieldorder="tt|tb|bb|bt" 		# Thoses identifies Interlaced videos https://ffmpeg.org/ffprobe-all.html

# ---------- END OF SETTINGS ---------------------

# ---------------- ENV VARIABLE -----------------------
ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg
ffprobe=/usr/lib/jellyfin-ffmpeg/ffprobe
# Allow to handle spaces in "for" loop
OIFS="$IFS"
IFS=$'\n'
# ---------------- ENV VARIABLE -----------------------

echo "----- Tonton Jo - 2022 -----" > $inputpath/checklog.txt
echo "- Starting Check of .mkv in $inputpath" >> $inputpath/checklog.txt

	for mkv in `find $inputpath | sort -h | grep .mkv`
	do
	echo "- Checking $mkv"
	echo "------------ $mkv ----------------" >> $inputpath/checklog.txt
	ffprobeoutput=$($ffprobe -hide_banner -show_streams "$mkv"  2>&1)
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedvideorange" ; then
		echo "$mkv - Found unwanted video range (unwantedvideorange)" >> $inputpath/checklog.txt
	fi
	if echo "$ffprobeoutput" | grep codec_name | grep -qi "$unwanted265format" ; then
		echo "$mkv - Unwanted format ($unwanted265format)" >> $inputpath/checklog.txt 
		if echo "$ffprobeoutput" | grep -Eqi "$unwantedcolormap" ; then
		echo "$mkv - Found HDR colors ($unwantedcolormap)" >> $inputpath/checklog.txt
		fi
	elif echo "$ffprobeoutput" | grep profile | grep -Eqi "$unwanted264format" ; then
			echo "$mkv - Unwanted format ($unwanted264format)" >> $inputpath/checklog.txt 
	fi
	if echo "$ffprobeoutput" | grep 'field_order' | grep -Eqi "$unwantedfieldorder" ; then
		echo "$mkv - File is interlaced" >> $inputpath/checklog.txt
	fi
	if  [[ $1 = "--ignore-sub" ]]; then
	echo "- Ignoring sub check"
	else
	if echo "$ffprobeoutput" | grep codec | grep -Eqi "$unwantedsub" ; then
	echo "$mkv - Unwanted subtitles format found ($unwantedsub)" >> $inputpath/checklog.txt
		if echo "$ffprobeoutput" | grep -qi tag | grep -qi "$forcedsub" ; then
			echo "$mkv - Forced subtitles found ($forcedsub)" >> $inputpath/checklog.txt
		fi
	fi
	fi
	if echo "$ffprobeoutput" | grep codec | grep -Eqi "$unwantedaudio" ; then
	echo "$mkv - Unwanted audio format found ($unwantedaudio)" >> $inputpath/checklog.txt
	fi
	done
