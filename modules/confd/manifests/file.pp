# SPDX-License-Identifier: Apache-2.0
# == Define confd::file
#
# Defines a service template to be monitored by confd,
# and the corresponding geneated config file.
#
# === Parameters
#
# [*prefix*] Prefix to use for all keys; it will actually be joined with the global
#            confd prefix
#
# [*watch_keys*] list of keys to watch relative to the value assigned in
#                $prefix.
#
# [*uid*] Numeric uid of the owner of the file produced. Default: 0
#
# [*gid*] Numeric gid of the owner of the produced file. Default: 0
#
# [*mode*] File mode for the generated file.
#
# [*reload*] Command to execute when the produced file changes
#
# [*check*] Check to execute when the produced file changes
#
# [*content*] The actual go text/template used for generating the file
#
# [*relative_prefix*] if true prepend the global prefix configured in the confd class
#
define confd::file (
    $ensure     = 'present',
    $prefix     = undef,
    $watch_keys = [],
    $uid        = undef,
    $gid        = undef,
    $mode       = '0444',
    $reload     = undef,
    $check      = undef,
    $content    = undef,
    Boolean $relative_prefix = true,
) {

    include confd

    $_prefix = $relative_prefix.bool2str("${confd::prefix}${prefix}", $prefix)
    $safe_name = regsubst($name, '/', '_', 'G')

    file { "/etc/confd/templates/${safe_name}.tmpl":
        ensure  => $ensure,
        mode    => '0400',
        content => $content,
        require => Package['confd'],
        before  => File["/etc/confd/conf.d/${safe_name}.toml"],
    }

    #TODO validate at least uid and guid
    file { "/etc/confd/conf.d/${safe_name}.toml":
        ensure  => $ensure,
        content => template('confd/service_template.toml.erb'),
        notify  => Service['confd'],
    }

    if $ensure == 'absent' {
        file { $name:
            ensure => 'absent',
        }
    }
}
