# Copyright (C) 2003-2008
# Emmanuel Saracco <esaracco@users.labs.libre-entreprise.org>
# Easter-eggs <http://www.easter-eggs.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330,
# Boston, MA 02111-1307, USA.

require 'clamav-lib.pl';

# module_uninstall ()
# IN: -
# OUT: -
#
# Called by Webmin when module is uninstalled
# 
sub module_uninstall
{
  # Remove quarantine purge cron
  &clamav_delete_cron ('purge');
  # Remove quanrantine update cron
  &clamav_delete_cron ('update');

  system (&has_command ('rm') . ' -f /etc/cron.d/webmin_clamav');
  system (&has_command ('rm') . ' -f /etc/cron.d/webmin_clamav.sav');

  # Restore original system files
  &clamav_system_restore (undef, 1);
}

1;
