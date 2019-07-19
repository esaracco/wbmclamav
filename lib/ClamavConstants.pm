package ClamavConstants;

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(

  ER_DAEMON_NOEXIST
  ER_DAEMON_CRONEXIST
  ER_CRON_DAEMONEXIST
  ER_MANUAL_CRONEXIST
  ER_MANUAL_DAEMONEXIST
  ER_CRON_PACKAGE

  KO
  OK

  NET_PING_OK

);

use constant {

  # Cron/daemon errors for clamav refresh method
  ER_DAEMON_NOEXIST => 2,
  ER_DAEMON_CRONEXIST => 3,
  ER_CRON_DAEMONEXIST => 4,
  ER_MANUAL_CRONEXIST => 5,
  ER_MANUAL_DAEMONEXIST => 6,
  ER_CRON_PACKAGE => 7,

  KO => 0,
  OK => 1,

  NET_PING_KO => 8

};

1;
