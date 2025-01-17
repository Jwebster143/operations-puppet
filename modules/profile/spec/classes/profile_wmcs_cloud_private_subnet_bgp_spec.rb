# SPDX-License-Identifier: Apache-2.0

require_relative '../../../../rake_modules/spec_helper'

describe 'profile::wmcs::cloud_private_subnet::bgp' do
  on_supported_os(WMFConfig.test_on(11, 11)).each do |os, facts|
    context "on #{os}" do
      let(:pre_condition) do
        "function dnsquery::a($fqdn) {
            if $fqdn == 'cloudlb2001-dev.private.codfw.wikimedia.cloud' {
                ['172.20.5.2', '127.0.0.1']
            } elsif $fqdn == 'cloudsw.private.codfw.wikimedia.cloud' {
                ['172.20.5.1', '127.0.0.2']
            } else {
                [$fqdn]
            }
        }"
      end
      let(:node_params) { { 'site' => 'codfw' } }
      let(:facts) { facts.merge({
        'hostname' => 'cloudlb2001-dev',
      }) }
      let(:params) {{
        'vlan_id' => 2151,
        'vips'    => {
            'openstack.codfw1dev.wikimediacloud.org' => {
                'ensure' => 'present',
                'check_cmd' => 'whatever',
                'service_type' => 'whatever',
                'address' => '185.15.57.24',
            },
            'other' => {
                'ensure' => 'present',
                'check_cmd' => 'whatever',
                'service_type' => 'whatever',
                'address' => '1.2.3.4',
            },
        },
      }}
      it { is_expected.to compile.with_all_deps }
      it {
          is_expected.to contain_class("profile::bird::anycast")
              .with_ipv4_src("172.20.5.2")
              .with_neighbors_list(["172.20.5.1"])
      }
      it {
        is_expected.to contain_file("/etc/iproute2/rt_tables.d/cloud-private.conf")
              .with_ensure("present")
              .with_content("100 cloud-private\n")
      }
      it {
        is_expected.to contain_interface__post_up_command("cloud-private_default_gw")
              .with_interface("vlan2151")
              .with_command("ip route add default via 172.20.5.1 table cloud-private")
      }
      it {
        is_expected.to contain_interface__post_up_command("cloud-private_route_lookup_rule_openstack.codfw1dev.wikimediacloud.org")
              .with_interface("vlan2151")
              .with_command("ip rule add from 185.15.57.24/32 table cloud-private")
      }
      it {
        is_expected.to contain_interface__post_up_command("cloud-private_route_lookup_rule_other")
              .with_interface("vlan2151")
              .with_command("ip rule add from 1.2.3.4/32 table cloud-private")
      }
    end
  end
end
