require "vagrant-simple-sync/version"
require "vagrant"

SIMPLE_SYNC_VAGRANT_API_VERSION = "2"

module VagrantPlugins
  module SimpleSync
    module Docker
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          argv = ARGV[1..-1]
          command = "docker #{argv.join(' ')}"
          with_target_vms(nil, :single_target => true) do |vm|
            env = vm.action(:ssh_run, :ssh_run_command => command)
            puts ""
            return env[:ssh_run_exit_status] || 0
          end
        end
      end
    end

    module AWSMeta
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          argv = ARGV[1..-1]
          if argv.length == 0
            puts "Usage: vagrant awsmeta <propery>"
            puts ""
            puts "Retrieves the value of <property> for the given instance or the instance's user-data if <property> is 'user-data'."
            puts "Pass 'list' to show the available EC2 properties."
            return 0
          end
          #Redirect stderr to /dev/null or it is output with stdout
          command = argv[0] == 'user-data' ? 'curl http://169.254.169.254/latest/user-data 2> /dev/null' : "curl http://169.254.169.254/latest/meta-data/#{argv[0] == 'list' ? '' : argv[0]} 2> /dev/null"
          with_target_vms(nil, :single_target => true) do |vm|
            env = vm.action(:ssh_run, :ssh_run_command => command)
            puts ""
            return env[:ssh_run_exit_status] || 0
          end
        end
      end
    end

    module AWSAMI
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          argv = ARGV[1..-1]
          if argv.length == 0
            puts "Usage: vagrant awsami <name>"
            puts ""
            puts "Creates a new AMI from the running EC2 instance with the given <name>."
            return 0
          end
          command = "/var/toto/setup-files/create-ami \"#{$aws_access_key_id}\" \"#{$aws_secret_access_key}\" \"#{argv[0] + DateTime.now.strftime('%Y%m%d')}\""
          with_target_vms(nil, :single_target => true) do |vm|
            env = vm.action(:ssh_run, :ssh_run_command => command)
            puts ""
            return env[:ssh_run_exit_status] || 0
          end
        end
      end
    end

    module RSync
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          machine_id = @env.active_machines.detect {|i| i[1] == :aws || i[1] == :digital_ocean || i[1] == :azure}
          if machine_id == nil
            return
          end
          machine = @env.machine(machine_id[0], machine_id[1])
          ssh_info = machine.ssh_info
          machine.config.vm.synced_folders.each do |id, data|
            hostpath = data[:hostpath]
            guestpath = data[:guestpath]
            puts "Syncing #{hostpath} -> #{guestpath}"
            command = [
              "rsync", "--verbose", "--archive", "-z",
              "--exclude", ".vagrant/",
              "-e", "ssh -p #{ssh_info[:port]} -o StrictHostKeyChecking=no -i '#{ssh_info[:private_key_path]}'",
              hostpath,
              "#{ssh_info[:username]}@#{ssh_info[:host]}:#{guestpath}"]
            r = Vagrant::Util::Subprocess.execute(*command)
            if r.exit_code != 0
              raise "Error syncing #{hostpath} -> #{guestpath}: #{r.stderr}"
            end
          end
        end
      end
    end

    module RSyncDeploy
      class Command < RSync::Command
        def execute
          super()
          puts "Restarting services"
          with_target_vms(nil, :single_target => true) do |vm|
            env = vm.action(:ssh_run, :ssh_run_command => "sudo /var/simple-sync.io/update-conf.py -p; sudo docker stop simple-sync-nginx; sudo /var/simple-sync.io/scripts/restart-services.sh; sleep 10; sudo docker start simple-sync-nginx")
            return env[:ssh_run_exit_status] || 0
          end
        end
      end
    end

    module Screen
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          with_target_vms(nil, :single_target => true) do |vm|
            vm.action(:ssh, :ssh_opts => {:extra_args => %w{-t screen -d -R Vagrant}})
            return 0
          end
        end
      end
    end

    module SSHFS
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          with_target_vms(nil, :single_target => true) do |vm|
            ssh_info = vm.ssh_info
            if ssh_info == nil
              puts "Machine offline"
              return -1
            end
            puts `sshfs -p #{ssh_info[:port]} #{ssh_info[:username]}@#{ssh_info[:host]}:#{ARGV.length > 2 ? ARGV[1] : "/vagrant"} #{ARGV[ARGV.length - 1]} -o IdentityFile=#{Array(ssh_info[:private_key_path]).first}`
            return 0
          end
        end
      end
    end

    module Restart
      class Command < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION, :command)
        def execute
          command = 'sudo /var/simple-sync.io/scripts/restart-services.sh; pgrep nginx ||sudo nginx;'
          with_target_vms(nil, :single_target => true) do |vm|
            env = vm.action(:ssh_run, :ssh_run_command => command)
            return env[:ssh_run_exit_status] || 0
          end
        end
      end
    end

    module Docker
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-docker"
        description "A proxy for running `docker` in your virtual machine over ssh."
        command :docker do
          Command
        end
      end
    end

    module SSHFS
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-sshfs"
        description "The `sshfs` command allows you to mount your virtual machine's file system over ssh."
        command :sshfs do
          Command
        end
      end
    end

    module Screen
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-screen"
        description "The `screen` command allows you to connect to your running virtual machine via screen over ssh."
        command :screen do
          Command
        end
      end
    end

    module AWSMeta
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-aws-meta"
        description "The `awsmeta` command allows you to retrieve an instance propery from your running EC2 instance."
        command :awsmeta do
          Command
        end
      end
    end

    module AWSAMI
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-aws-ami"
        description "The `awsami` command allows you to create an AMI from your running EC2 instance."
        command :awsami do
          Command
        end
      end
    end

    module RSync
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-rsync"
        description "The `rsyncmanual` command syncs your local folders to your running remote instance using rsync."
        command :rsyncmanual do
          Command
        end
      end
    end

    module RSyncDeploy
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-rsyncdeploy"
        description "The `rsyncdeploy` command syncs your local folders to your running remote instance using rsync, updates the config to prod and restarts the services."
        command :rsyncdeploy do
          Command
        end
      end
    end

    module Restart
      class Plugin < Vagrant.plugin(SIMPLE_SYNC_VAGRANT_API_VERSION)
        name "vagrant-restart"
        description "The `restart` command restarts services on the VM so they pick up the latest changes."
        command :restart do
          Command
        end
      end
    end
  end
end
