# Jellyfin

## Tonton Jo  
### Join the community:
[![Youtube channel](https://github-readme-youtube-stats.herokuapp.com/subscribers/index.php?id=UCnED3K6K5FDUp-x_8rwpsZw&key=AIzaSyA3ivqywNPQz0xFZBHfPDKzh1jFH5qGD_g)](http://youtube.com/channel/UCnED3K6K5FDUp-x_8rwpsZw?sub_confirmation=1)
[![Discord Tonton Jo](https://badgen.net/discord/members/h6UcpwfGuJ?label=Discord%20Tonton%20Jo%20&icon=discord)](https://discord.gg/h6UcpwfGuJ)
### Support the channel with one of the following link:
[![Ko-Fi](https://badgen.net/badge/Buy%20me%20a%20Coffee/Link?icon=buymeacoffee)](https://ko-fi.com/tontonjo)
[![Infomaniak](https://badgen.net/badge/Infomaniak/Affiliated%20link?icon=K)](https://www.infomaniak.com/goto/fr/home?utm_term=6151f412daf35)
[![Express VPN](https://badgen.net/badge/Express%20VPN/Affiliated%20link?icon=K)](https://www.xvuslink.com/?a_fid=TontonJo)  

## HDRtoSDR_converter.sh
### Convert your H265 HDR content to H264 SDR while keeping HDR colors using Tonemap

### Prerequisits:
- A working GPU decoding setup in jellyfin  
- Install needed dependencies IN container to have tonemap  
```shell
docker exec -it $jellyfin bash
```  
```shell
echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list  
apt-get update  
apt-get install aptitude
aptitude install nvidia-opencl-icd
```

### Usage:  
It will look in $inputpath for HDR content and convert them to x264 SDR to $outputpath  
Executing the script like this works but is not perfect - suggestions welcome!

- Put script in a jellyfin container accessible folder
- Edit the configuration in the script - for more informations about settings: https://trac.ffmpeg.org/wiki/Encode/H.264
- - Input path - script will recurse if there are subfolders
- - Outputpath - Where to put converter files - set another path than input
- - CRF - The range of the CRF scale is 0–51, where 0 is lossless
- - Preset - Use the slowest preset that you have patience for: ultrafast,superfastveryfast,faster,fast,medium,slow,slower,veryslow,placebo
- - Tune - film,animation,grain,stillimage,fastdecode,zerolatency 
- - MaxRate - target bitrate in bps
- Make it executable 
```shell
docker exec $jellyfin chmod +x /path/to/HDRtoSDR_converter.sh
```
- Run it
- - Connect into container
```shell
docker exec -it $jellyfin bash
```
- - Run for every movie in $inputpath
```shell
bash /path/to/HDRtoSDR_converter.sh
```
- - Run it for a single movie 
```shell
bash /path/to/HDRtoSDR_converter.sh /path/to/movie.mkv
```

### Known problems:  
- When cancelling process, worker still continue in container - help and infos welcome!
