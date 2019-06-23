# System files to backup
# path => [1 = empty it after backup | 0 = do not empty it]
%system_files = (
  $config{"clamav_freshclam_init_script"} => 0,
  $config{"clamav_freshclam_conf"} => 0,
  $config{"clamav_init_script"} => 0,
  $config{"clamav_clamav_conf"} => 0,
  "/etc/rc.conf" => 0,
  "/etc/network/if-up.d/clamav-freshclam-ifupdown" => 0,
  "/etc/network/if-down.d/clamav-freshclam-ifupdown" => 0,
  "/etc/cron.d/clamav-freshclam" => 1,
  "/etc/cron.daily/clamav-data" => 1,
  "/var/lib/clamav/interface" => 1,
);
