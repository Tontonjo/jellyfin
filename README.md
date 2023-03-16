# Jellyfin

## Tonton Jo  
### Join the community:
[![Youtube](https://badgen.net/badge/Youtube/Subscribe)](http://youtube.com/channel/UCnED3K6K5FDUp-x_8rwpsZw?sub_confirmation=1)
[![Discord Tonton Jo](https://badgen.net/discord/members/h6UcpwfGuJ?label=Discord%20Tonton%20Jo%20&icon=discord)](https://discord.gg/h6UcpwfGuJ)
### Support my work, give a thanks and help the youtube channel:
[![Ko-Fi](https://badgen.net/badge/Buy%20me%20a%20Coffee/Link?icon=buymeacoffee)](https://ko-fi.com/tontonjo)
[![Infomaniak](https://badgen.net/badge/Infomaniak/Affiliated%20link?icon=K)](https://www.infomaniak.com/goto/fr/home?utm_term=6151f412daf35)
[![Express VPN](https://badgen.net/badge/Express%20VPN/Affiliated%20link?icon=K)](https://www.xvuslink.com/?a_fid=TontonJo)  

## jellyfin_compatibility_converter.sh
### Convert your files in the most compatible format for Jellyfin clients

### Prerequisits:
This script is intended to be executed from Jellyfin but should work with every ffmpeg installation
- ffmpeg  
- A working GPU decoding setup if you want GPU transcode
- - Install needed dependencies IN container to have tonemap  

### enable tonemap capability for GPU:
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
It will look in $inputpath for MKV movies and convert them to x264 SDR to $outputpath
I recommand using tmux to start process
- Put script in a jellyfin container accessible folder
- If no outputpath is specified, original file will be overwritten
- You can set a maximum amount of files to process
- Use arguments to process only video or audio
- Specify a blacklist

- Make it executable 
```shell
docker exec $jellyfin chmod +x jellyfin_compatibility_converter.sh
```
- Run it
- - Connect into container
```shell
docker exec -u root:users -it $jellyfin bash
```
- - Run for every movie in $inputpath
```shell
bash jellyfin_compatibility_converter.sh
```


## compatibility_checker.sh
### Want to know what files contains not well supported format by jellyfin? Here you go


### Usage:  
It will look in $inputpath for HDR content and convert them to x264 SDR to $outputpath  
Executing the script like this works but is not perfect - suggestions welcome!

- Put script in a jellyfin container accessible folder
- Edit the configuration in the script especially the path
- - Input path - script will recurse if there are subfolders

- Run it
- - Connect into container
```shell
docker exec -it $jellyfin bash
```
- - Run for every movie in $inputpath
```shell
bash /path/to/compatibility_checker.sh
```
