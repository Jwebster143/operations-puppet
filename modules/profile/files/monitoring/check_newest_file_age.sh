#!/bin/sh
# SPDX-License-Identifier: MIT
#
# NOTE: This file is managed by Puppet.
# Originally copied from https://github.com/thehunmonkgroup/nagios-plugin-newest-file-age
#
# Newest file in a directory plugin for Nagios.
# Written by Chad Phillips (chad@apartmentlines.com)
# Last Modified: 2009-02-12
#
# The MIT License (MIT)
#
# Copyright (c) 2015 thehunmonkgroup
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


PROGPATH=`dirname $0`

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4

print_usage() {
    echo "
Usage: check_newest_file_age --dirs | -d <directories> [-w <max_age>] [-c <max_age>] [-W] [-C] [-t <time_unit>] [-V] [--check-dirs] [--base-dir <directory>]
Usage: check_newest_file_age --help | -h

Description:

This plugin pulls the most recently created file in each specified directory,
and checks it's created time against the current time.  If the maximum age of
the file is exceeded, a warning/critical message is returned as appropriate.

This is useful for examining backup directories for freshness.

Tested to work on Linux/FreeBSD/OS X.

The following arguments are accepted:

  --dirs | -d     A space separated list of directories to examine.  Each
                  directory will be checked for the newest created file in that
                  directory.

  -w              (Optional) Generate a warning message if the last created
                  file is older than this value.  Defaults to 26 hours.

  -c            (Optional) Generate a critical message if the last created
                  file is older than this value.  Defaults to 52 hours.

  -W              (Optional) If set, a warning message will be returned if the
                  specified directory doesn't exist, or there are no checkable
                  files in the specified directory.

  -C              (Optional) If set, a critical message will be returned if the
                  specified directory doesn't exist, or there are no checkable
                  files in the specified directory.

  -t              (Optional) The time unit used for the -w and -c values.  Must
                  be one of: seconds, minutes, hours, days.  Defaults to hours.

  -V              (Optional) Output verbose information about all checked
                  directories.  Default is only to print verbose information
                  for directories with non-OK states.

  --check-dirs    (Optional) If set, directories inside the specified directory
                  will also be checked for their creation time. Note that this
                  check is not recursive.  Without this option, only real files
                  inside the specified directory will be checked.

  --base-dir      (Optional) If set, this path will be prepended to all
                  checked directories.

  --help | -h     Print this help and exit.

Examples:

Generate a warning if the newest file in /backups is more than 26 hours old,
and a critical if it's more than 52 hours old...

  check_newest_file_age -d \"/backups\"

Generate a warning if the newest file in /backups/bill or /backups/dave is more
than one week old, or a critical if it's more than two weeks old...

  check_newest_file_age -d \"/backups/bill /backups/dave\" -w 7 -c 14 -t days

Caveats:

Although multiple directories can be specified, only one set of
warning/critical times can be supplied.

Linux doesn't seem to have an easy way to check file/directory creation time,
so file/directory last modification time is used instead.
"
}

print_help() {
    print_usage
    echo "Newest file in a directory plugin for Nagios."
    echo ""
}

# Sets the exit status for the plugin.  This is done in such a way that the
# status can only go in one direction: OK -> WARNING -> CRITICAL.
set_exit_status() {
  new_status=$1
  # Nothing needs to be done if the state is already critical, so exclude
  # that case.
  case $exitstatus
  in
    $STATE_WARNING)
      # Only upgrade from warning to critical.
      if [ "$new_status" = "$STATE_CRITICAL" ]; then
        exitstatus=$new_status;
      fi
    ;;
    $STATE_OK)
      # Always update state if current state is OK.
      exitstatus=$new_status;
    ;;
  esac
}

# Make sure the correct number of command line
# arguments have been supplied
if [ $# -lt 1 ]; then
    print_usage
    exit $STATE_UNKNOWN
fi

# Defaults.
exitstatus=$STATE_OK
warning=26
critical=52
time_unit=hours
verbose=
on_empty=$STATE_OK
check_dirs=
base_dir=

# Grab the command line arguments.
while test -n "$1"; do
    case "$1" in
        --help)
            print_help
            exit $STATE_OK
            ;;
        -h)
            print_help
            exit $STATE_OK
            ;;
        --dirs)
            dirs=$2
            shift
            ;;
        -d)
            dirs=$2
            shift
            ;;
        -w)
            warning=$2
            shift
            ;;
        -c)
            critical=$2
            shift
            ;;
    -W)
      on_empty=$STATE_WARNING
            ;;
    -C)
      on_empty=$STATE_CRITICAL
            ;;
        -t)
            time_unit=$2
            shift
            ;;
    -V)
      verbose=1
            ;;
        --check-dirs)
            check_dirs=1
            ;;
    --base-dir)
          base_dir=$2
      shift
      ;;
        -x)
            exitstatus=$2
            shift
            ;;
        --exitstatus)
            exitstatus=$2
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            print_usage
            exit $STATE_UNKNOWN
            ;;
    esac
    shift
done

if [ ! "$dirs" ]; then
  echo "No directories provided."
  exit $STATE_UNKNOWN
fi

if [ `echo "$warning" | grep [^0-9]` ] || [ ! "$warning" ]; then
  echo "Warning value must be a number."
  exit $STATE_UNKNOWN
fi

if [ `echo "$critical" | grep [^0-9]` ] || [ ! "$critical" ]; then
  echo "Critical value must be a number."
  exit $STATE_UNKNOWN
fi

if [ ! `echo "$time_unit" | grep "seconds\|minutes\|hours\|days"` ]; then
  echo "Time unit must be one of: seconds, minutes, hours, days."
  exit $STATE_UNKNOWN
fi

if [ "$warning" -ge "$critical" ]; then
  echo "Critical time must be greater than warning time."
  exit $STATE_UNKNOWN
fi

case $time_unit
in
  days)
    multiplier=86400;
    abbreviation="days";
  ;;
  hours)
    multiplier=3600;
    abbreviation="hrs";
  ;;
  minutes)
    multiplier=60;
    abbreviation="mins";
  ;;
  *)
    multiplier=1
    abbreviation="secs";
  ;;
esac

# Starting values.
DIR_COUNT=0
OK_FILE_COUNT=0
OUTPUT=
CURRENT_TIME=`date +%s`
OS_DISTRO=`uname -s`

# Loop through each provided directory.
for dir in $dirs
do
  check_file=
  DIR_COUNT=$(($DIR_COUNT + 1))

  # Check if dir exists.
  full_path=${base_dir}${dir}
  if [ -d "$full_path" ]; then
    file_list=`ls -t $full_path`
    # Cycle through files, looking for a checkable file.
    for next_file in $file_list
    do
      next_filepath=$full_path/$next_file
      if [ "$check_dirs" ]; then
        # Check if it's a file or directory.
        if [ -f "$next_filepath" ] || [ -d "$next_filepath" ]; then
          check_file=1
        fi
      else
        # Check if it's a file.
        if [ -f "$next_filepath" ]; then
          check_file=1
        fi
      fi
      if [ "$check_file" ]; then
        # stat doesn't work the same on Linux and FreeBSD/Darwin, so
        # make adjustments here.
        if [ "$OS_DISTRO" = "Linux" ]; then
          st_ctime=`stat --printf=%Y ${next_filepath}`
        else
          eval $(stat -s ${next_filepath})
        fi

        FILE_AGE=$(($CURRENT_TIME - $st_ctime))
        FILE_AGE_UNITS=$(($FILE_AGE / $multiplier))
        MAX_WARN_AGE=$(($warning * $multiplier))
        MAX_CRIT_AGE=$(($critical * $multiplier))
        if [ $FILE_AGE -gt $MAX_CRIT_AGE ]; then
          OUTPUT="$OUTPUT ${dir}: ${FILE_AGE_UNITS}${abbreviation}"
          set_exit_status $STATE_CRITICAL
        elif [ $FILE_AGE -gt $MAX_WARN_AGE ]; then
          OUTPUT="$OUTPUT ${dir}: ${FILE_AGE_UNITS}${abbreviation}"
          set_exit_status $STATE_WARNING
        else
          OK_FILE_COUNT=$(($OK_FILE_COUNT + 1))
          if [ "$verbose" ]; then
            OUTPUT="$OUTPUT ${dir}: ${FILE_AGE_UNITS}${abbreviation}"
          fi
        fi
        break
      fi
    done
    # Check here to see if any files got tested in the directory.
    if [ ! "$check_file" ]; then
      set_exit_status $on_empty
      OUTPUT="$OUTPUT ${dir}: No files"
      # If empty is an OK state, then increment the ok file count.
      if [ "$on_empty" = "$STATE_OK" ]; then
        OK_FILE_COUNT=$(($OK_FILE_COUNT + 1))
      fi
    fi
  else
    set_exit_status $on_empty
    OUTPUT="$OUTPUT ${dir}: Does not exist"
  fi
done

case $exitstatus
in
  $STATE_CRITICAL)
    exit_message="CRITICAL";
  ;;
  $STATE_WARNING)
    exit_message="WARNING";
  ;;
  $STATE_OK)
    exit_message="OK";
  ;;
  *)
    exitstatus=$STATE_UNKNOWN;
    exit_message="UNKNOWN";
  ;;
esac

exit_message="${exit_message}: ${OK_FILE_COUNT}/${DIR_COUNT}"

if [ "$OUTPUT" ]; then
  exit_message="${exit_message} --${OUTPUT}"
fi

echo "$exit_message"
exit $exitstatus
