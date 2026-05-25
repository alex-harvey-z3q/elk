# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'tmpdir'

class AcceptanceSetup
  include PuppetLitmus

  CODE_DIR = '/etc/puppetlabs/code'
  MODULE_DIR = "#{CODE_DIR}/environments/production/modules"
  FACT_DIR = '/etc/facter/facts.d'
  REMOTE_TMP = '/tmp/elk-litmus'

  def prepare
    system('bundle exec rake spec_prep') || raise('spec_prep failed')
    stage_modules do |module_archive|
      run_shell("rm -rf #{REMOTE_TMP} #{MODULE_DIR} #{CODE_DIR}/hieradata #{FACT_DIR}/facts.d")
      run_shell("mkdir -p #{REMOTE_TMP} #{MODULE_DIR} #{CODE_DIR} #{FACT_DIR}")
      bolt_upload_file(module_archive, "#{REMOTE_TMP}/modules.tar.gz")
      run_shell("tar -xzf #{REMOTE_TMP}/modules.tar.gz -C #{MODULE_DIR}")
    end

    bolt_upload_file('spec/fixtures/hiera.yaml.acceptance', "#{CODE_DIR}/hiera.yaml")
    bolt_upload_file('spec/fixtures/hieradata', "#{CODE_DIR}/hieradata")

    run_shell('dnf -y install iptables-services lvm2 curl')
    run_shell('systemctl enable --now iptables.service')
    run_shell('systemctl enable --now ip6tables.service')
  end

  private

  def stage_modules
    Dir.mktmpdir('elk-litmus-modules') do |tmpdir|
      archive = File.join(tmpdir, 'modules.tar.gz')
      modules = File.join(tmpdir, 'modules')
      FileUtils.mkdir_p(modules)

      modules_dir = File.join(Dir.pwd, 'spec', 'fixtures', 'modules')
      Dir.children(modules_dir).sort.each do |entry|
        next if entry == 'elk'

        source = File.join(modules_dir, entry)
        target = File.join(modules, entry)
        FileUtils.cp_r(File.realpath(source), target)
      end

      tar_command = [
        'tar',
        '-C',
        Shellwords.escape(modules),
        '-czf',
        Shellwords.escape(archive),
        '.'
      ].join(' ')
      system(tar_command) || raise('module archive creation failed')

      yield archive
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    AcceptanceSetup.new.prepare
  end
end
