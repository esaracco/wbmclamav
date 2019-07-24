<p align="center"><img src="https://wbmclamav.esaracco.fr/images/wbmclamav.png"/></p>

# wbmclamav

[Project homepage](https://wbmclamav.esaracco.fr)

wbmclamav is a [Webmin](http://www.webmin.com) module to manage the [ClamAV](https://www.clamav.net) antivirus. It can be used to update ClamAV / Freshclam configuration, manage quarantine, search in the viruses database and keep it up-to-date, scan local directories, control remote ClamAV,  extract signatures from new viruses, and so on.

## Installation

### From a wbm archive:

Open the Webmin modules manager and upload the wbmclamav file.

### From the Git repository:

1. Rename your local Git repository (optional):
```bash
mv wbmclamav/ clamav/
```
2. Build a gzipped tarball archive:
```bash
tar zcvf wbmclamav.wbm.gz clamav/
```
3. Open the Webmin modules manager and upload your brand new wbmclamav file.

## Perl dependencies

You need at least the following Perl modules in order to run wbmclamav:

- Date::Manip
- File::Basename
- File::Path
- File::Find
- File::Copy
- HTML::Entities
- IO::Socket
- POSIX

Depending on the software installed on your system and your wbmclamav configuration options, you may also need the following modules:

- Compress::Zlib
- GD
- GD::Graph::lines
- Getopt::Long
- IO::File
- LWP::UserAgent
- Mail::Internet
- Mail::Mbox::MessageParser
- Mail::SpamAssassin
- Net::SMTP

All those modules can be loaded from CPAN.

As root you can try:

```bash
# perl -MCPAN -e shell
CPAN Shell> install module1 module2 ...
```

## License
GPL
