# wbmclamav

[Project homepage](http://wbmclamav.esaracco.fr)

wbmclamav is a [Webmin](http://www.webmin.com) module to manage the [ClamAV](https://www.clamav.net) antivirus. It can be used to update ClamAV / Freshclam configuration, manage quarantine, search in the viruses database and keep it up-to-date, scan local directories, control remote ClamAV,  extract signatures from new viruses, and so on.

## Installation

### From a wbm archive :

Open the Webmin modules manager and upload the wbmclamav file.

### From the Git repository :

1. Change the owner and permissions of the entire tree :
```bash
chmod -R 755 clamav/
chown -R root:bin clamav/
```
2. Build a gzipped tarball archive :
```bash
tar zcvf wbmclamav.wbm.gz clamav/
```
3. Open the Webmin modules manager and upload your brand new wbmclamav file.

## License
GPL
