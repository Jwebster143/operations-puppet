# SPDX-License-Identifier: Apache-2.0
require_relative '../../../../rake_modules/spec_helper'
describe 'debian::codename::gt' do
  on_supported_os(supported_os: ['operatingsystem' => 'Debian', 'operatingsystemrelease' => ['9']]).each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      it { is_expected.to run.with_params('buster').and_return(false) }
      it { is_expected.to run.with_params('stretch').and_return(false) }
      it { is_expected.to run.with_params('bullseye', 'bullseye').and_return(false) }
      it { is_expected.to run.with_params('bullseye', 'bookworm').and_return(true) }
      it { is_expected.to run.with_params('bullseye', 'buster').and_return(false) }
    end
  end
end
