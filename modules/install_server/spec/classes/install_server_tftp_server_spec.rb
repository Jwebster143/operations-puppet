require_relative '../../../../rake_modules/spec_helper'

describe 'install_server::tftp_server', :type => :class do
  on_supported_os(WMFConfig.test_on).each do |os, facts|
    context "On #{os}" do
      let(:facts){ facts }
      let(:params) { { 'ztp_juniper_root_password' => 'dummy' } }

      it { is_expected.to compile }
      it { is_expected.to contain_package('atftpd').with_ensure('present') }
      it do
        is_expected.to contain_file('/etc/default/atftpd').with({
          'mode'   => '0444',
          'owner'  => 'root',
          'group'  => 'root',
        })
      end
      it do
        is_expected.to contain_file('/srv/tftpboot').with({
          'mode'    => '0444',
          'owner'   => 'root',
          'group'   => 'root',
          'recurse' => 'remote',
        })
      end
    end
  end
end
