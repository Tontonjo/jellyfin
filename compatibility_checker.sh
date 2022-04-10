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
# 1.2 - Fix some detections


# ------------- Settings -------------------------
inputpath=/media/films
unwantedsub="pgs"
unwantedformat="HEVC|265"
unwantedaudio="dts|ac3"
unwantedcolormap="smpte2084|bt2020nc|bt2020"

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
	ffprobeoutput=$($ffprobe -show_streams $mkv)
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedformat" ; then
		echo "$mkv - Unwanted format ($unwantedformat)" >> $inputpath/checklog.txt 
		if $ffprobe -show_streams $mkv | grep -Eqi "$unwantedcolormap" ; then
		echo "$mkv - Found HDR colors ($unwantedcolormap)" >> $inputpath/checklog.txt
		fi
	fi
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedsub" ; then
	echo "$mkv - Unwanted subtitles format found ($unwantedsub)" >> $inputpath/checklog.txt
	fi
	if echo "$ffprobeoutput" | grep -Eqi "$unwantedaudio" ; then
	echo "$mkv - Unwanted audio format found ($unwantedaudio)" >> $inputpath/checklog.txt
	fi
	done
