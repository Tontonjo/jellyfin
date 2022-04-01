# Jellyfin

## Tonton Jo  
### Join the community:
[![Youtube channel](https://github-readme-youtube-stats.herokuapp.com/subscribers/index.php?id=UCnED3K6K5FDUp-x_8rwpsZw&key=AIzaSyA3ivqywNPQz0xFZBHfPDKzh1jFH5qGD_g)](http://youtube.com/channel/UCnED3K6K5FDUp-x_8rwpsZw?sub_confirmation=1)
[![Discord Tonton Jo](https://badgen.net/discord/members/2NQskxZjfp?label=Discord%20Tonton%20Jo%20&icon=discord)](https://discord.gg/N3ssTdTS)
### Support the channel with one of the following link:
[![Ko-Fi](https://badgen.net/badge/Buy%20me%20a%20Coffee/Link?icon=buymeacoffee)](https://ko-fi.com/tontonjo)
[![Infomaniak](https://badgen.net/badge/Infomaniak/Affiliated%20link?icon=K)](https://www.infomaniak.com/goto/fr/home?utm_term=6151f412daf35)
[![Express VPN](https://badgen.net/badge/Express%20VPN/Affiliated%20link?icon=K)](https://www.xvuslink.com/?a_fid=TontonJo)  


## HDRtoSDR_converter.sh
This scripts aim to convert H265 HDR content to H264 SDR while trying to keep HDR colors using Tonemap  
It will look in $inputpath for HDR content and convert them to x264 SDR to $outputpath  

### Prerequisits:
- A working GPU decoding setup in jellyfin  
- Install needed dependencies to have tonemap  
```shell
echo "deb http://deb.debian.org/debian buster-backports main contrib non-free" >> /etc/apt/sources.list  
apt-get update  
apt-get install aptitude
aptitude install nvidia-opencl-icd
```
### Usage:
- Put script in a jellyfin container accessible folder
- Edit path to match your needs and environement
- Make it executable 
```shell
docker exec jellyfin chmod +x /media/HDRtoSDR_converter.sh
```
- Run it  
```shell
docker exec jellyfin /media/HDRtoSDR_converter.sh
```
