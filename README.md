<p align="center"><img src="https://wbmclamav.esaracco.fr/images/wbmclamav.png"/></p>

# wbmclamav

[Project homepage](https://wbmclamav.esaracco.fr)

wbmclamav is a [Webmin](http://www.webmin.com) module to manage the [ClamAV](https://www.clamav.net) antivirus. It can be used to update ClamAV / Freshclam configuration, manage quarantine, search in the viruses database and keep it up-to-date, scan local directories, control remote ClamAV,  extract signatures from new viruses, and so on.

## Installation

### From a wbm archive:

Open the Webmin modules manager and upload the wbmclamav file.

### From the Git repository:

1. Change the owner and permissions of the entire tree:
```bash
chmod -R 755 clamav/
chown -R root:bin clamav/
```
2. Build a gzipped tarball archive:
```bash
tar zcvf wbmclamav.wbm.gz clamav/
```
3. Open the Webmin modules manager and upload your brand new wbmclamav file.

## Perl dependencies

You need at least the following Perl modules in order to run wbmclamav:

- Compress::Zlib
- Date::Manip
- File::Basename
- File::Path
- File::Find
- File::Copy
- GD
- GD::Graph::lines
- Getopt::Long
- HTML::Entities
- IO::File
- IO::Socket
- Mail::Internet
- Mail::Mbox::MessageParser
- Mail::SpamAssassin
- Net::SMTP
- POSIX

They can be loaded for free from CPAN.

As 'root' you can try:

```bash
# perl -MCPAN -e shell
CPAN Shell> install Compress::Zlib Date::Manip File::Basename File::Path
CPAN Shell> install File::Find File::Copy GD GD::Graph::lines
CPAN Shell> install Getopt::Long HTML::Entities IO::File IO::Socket
CPAN Shell> install Mail::Internet Mail::Mbox::MessageParser Mail::SpamAssassin
CPAN Shell> install Net::SMTP POSIX
```

If other modules needs to be installed as well in order for this
module to work properly, please let CPAN install them for you as well.

## License
GPL
