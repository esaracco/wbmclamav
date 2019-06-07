# wbmclamav

[Project homepage](http://wbmclamav.esaracco.fr)

wbmclamav is a [Webmin](http://www.webmin.com) module to manage the [ClamAV](https://www.clamav.net) antivirus.

## Installation

### From a wbm archive :

Open the Webmin modules manager and upload the wbmclamav file.

### From the Git repository :

1. Change the owner and permissions of the entire tree :
```bash
chmod -R 755 wbmclamav/
chown -R root:bin wbmclamav/
```
2. Build a gzipped tarball archive :
```bash
tar zcvf wbmclamav.wbm.gz wbmclamav/
```
3. Open the Webmin modules manager and upload your brand new wbmclamav file.

## License
GPL
