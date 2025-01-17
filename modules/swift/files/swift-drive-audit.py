#!/usr/bin/env python
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2010-2012 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Upon exit, the following will be bitwise OR-ed:
# EX_OK: no errors found in log files
# 2: a device was unmounted
# 4: a device was unavailable while unmounting

import datetime
import glob
import os
import re
import subprocess
import sys
from ConfigParser import ConfigParser

from swift.common.utils import backward, get_logger

EX_DEV_UNMOUNTED = 2
EX_DEV_UNAVAILABLE = 4


def get_devices(device_dir, logger):
    devices = []
    for line in open('/proc/mounts').readlines():
        data = line.strip().split()
        block_device = data[0]
        mount_point = data[1]
        if mount_point.startswith(device_dir):
            device = {}
            device['mount_point'] = mount_point
            device['block_device'] = block_device
            try:
                device_num = os.stat(block_device).st_rdev
            except OSError:
                # If we can't stat the device, then something weird is going on
                logger.error("Error: Could not stat %s!" %
                             block_device)
                continue
            device['major'] = str(os.major(device_num))
            device['minor'] = str(os.minor(device_num))
            devices.append(device)
    for line in open('/proc/partitions').readlines()[2:]:
        major, minor, blocks, kernel_device = line.strip().split()
        device = [d for d in devices
                  if d['major'] == major and d['minor'] == minor]
        if device:
            device[0]['kernel_device'] = kernel_device
    return devices


def get_errors(error_re, log_file_pattern, minutes):
    # Assuming log rotation is being used, we need to examine
    # recently rotated files in case the rotation occurred
    # just before the script is being run - the data we are
    # looking for may have rotated.
    #
    # The globbing used before would not work with all out-of-box
    # distro setup for logrotate and syslog therefore moving this
    # to the config where one can set it with the desired
    # globbing pattern.
    log_files = [f for f in glob.glob(log_file_pattern)]
    log_files.sort()

    now_time = datetime.datetime.now()
    end_time = now_time - datetime.timedelta(minutes=minutes)
    # kern.log does not contain the year so we need to keep
    # track of the year and month in case the year recently
    # ticked over
    year = now_time.year
    prev_entry_month = now_time.month
    errors = {}

    reached_old_logs = False
    for path in log_files:
        try:
            f = open(path)
        except IOError:
            logger.error("Error: Unable to open " + path)
            print("Unable to open " + path)
            sys.exit(os.EX_OSFILE)
        for line in backward(f):
            if '[    0.000000]' in line \
                or 'KERNEL supported cpus:' in line \
                    or 'BIOS-provided physical RAM map:' in line:
                # Ignore anything before the last boot
                reached_old_logs = True
                break
            # Solves the problem with year change - kern.log does not
            # keep track of the year.
            log_time_entry = line.split()[:3]
            if log_time_entry[0] == 'Dec' and prev_entry_month == 'Jan':
                year -= 1
            prev_entry_month = log_time_entry[0]
            log_time_string = '%s %s' % (year, ' '.join(log_time_entry))
            try:
                log_time = datetime.datetime.strptime(
                    log_time_string, '%Y %b %d %H:%M:%S')
            except ValueError:
                continue
            if log_time > end_time:
                for err in error_re:
                    for device in err.findall(line):
                        errors[device] = errors.get(device, 0) + 1
            else:
                reached_old_logs = True
                break
        if reached_old_logs:
            break
    return errors


def comment_fstab(mount_point):
    with open('/etc/fstab', 'r') as fstab:
        with open('/etc/fstab.new', 'w') as new_fstab:
            for line in fstab:
                parts = line.split()
                if len(parts) > 2 and line.split()[1] == mount_point:
                    new_fstab.write('#' + line)
                else:
                    new_fstab.write(line)
    os.rename('/etc/fstab.new', '/etc/fstab')


if __name__ == '__main__':
    c = ConfigParser()
    try:
        conf_path = sys.argv[1]
    except Exception:
        print "Usage: %s CONF_FILE" % sys.argv[0].split('/')[-1]
        sys.exit(os.EX_USAGE)
    if not c.read(conf_path):
        print "Unable to read config file %s" % conf_path
        sys.exit(os.EX_CONFIG)

    conf = dict(c.items('drive-audit'))
    conf['log_name'] = conf.get('log_name', 'drive-audit')
    logger = get_logger(conf, log_route='drive-audit')

    device_dir = conf.get('device_dir', '/srv/node')
    minutes = int(conf.get('minutes', 60))
    error_limit = int(conf.get('error_limit', 1))
    log_file_pattern = conf.get('log_file_pattern',
                                '/var/log/kern.*[!.][!g][!z]')
    error_re = []
    for conf_key in conf:
        if conf_key.startswith('regex_pattern_'):
            error_pattern = conf[conf_key]
            try:
                r = re.compile(error_pattern)
            except re.error:
                logger.error('Error: unable to compile regex pattern "%s"' %
                             error_pattern)
                sys.exit(os.EX_DATAERR)
            error_re.append(r)
    if not error_re:
        error_re = [
            re.compile(r'\berror\b.*\b(sd[a-z]{1,2}\d?)\b'),
            re.compile(r'\b(sd[a-z]{1,2}\d?)\b.*\berror\b'),
        ]
    devices = get_devices(device_dir, logger)
    logger.debug("Devices found: %s" % str(devices))
    if not devices:
        logger.error("Error: No devices found!")
    errors = get_errors(error_re, log_file_pattern, minutes)
    logger.debug("Errors found: %s" % str(errors))
    unmounts = 0
    exitcode = os.EX_OK
    for kernel_device, count in errors.items():
        if count >= error_limit:
            device = \
                [d for d in devices if d['kernel_device'] == kernel_device]
            if not device:
                exitcode = exitcode | EX_DEV_UNAVAILABLE
                logger.info("Errors found but device unavailable: %s:%s" %
                            (kernel_device, count))
                continue
            mount_point = device[0]['mount_point']
            if mount_point.startswith(device_dir):
                logger.info("Unmounting %s with %d errors" %
                            (mount_point, count))
                subprocess.call(['umount', '-fl', mount_point])
                logger.info("Commenting out %s from /etc/fstab" %
                            (mount_point))
                comment_fstab(mount_point)
                unmounts += 1
                exitcode = exitcode | EX_DEV_UNMOUNTED
    if unmounts == 0:
        logger.info("No drives were unmounted")
    sys.exit(exitcode)
