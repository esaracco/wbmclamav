# Copyright (C) 2003-2019
# Emmanuel Saracco <emmanuel@esaracco.fr>
#
# GNU GENERAL PUBLIC LICENSE

BEGIN {

  unshift (@INC, $ENV{'FOREIGN_ROOT_DIRECTORY'}.'/'.
                   $ENV{'FOREIGN_MODULE_NAME'}.'/lib');
};

use ClamavConstants;
require 'clamav-lib.pl';

# module_uninstall ()
#
# Called by Webmin when module is uninstalled.
# 
sub module_uninstall
{
  # Remove quarantine purge cron
  &clamav_delete_cron ('purge');
  # Remove quanrantine update cron
  &clamav_delete_cron ('update');

  unlink ('/etc/cron.d/webmin_clamav');
  unlink ('/etc/cron.d/webmin_clamav.sav');

  # Restore original system files
  &clamav_system_restore (undef, 1);
}

1;
