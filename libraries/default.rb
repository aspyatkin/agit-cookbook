require 'fileutils'

module ChefCookbook
  module AgitHelper
    def self.ssh_auth_sock
      ::Dir.glob('/tmp/ssh*/agent*').find do |sock_path|
        agent_pid = sock_path.match(/agent\.(\d+)$/)[1].to_i
        parent_pid = ::Process.pid
        while parent_pid != 1
          data = ::IO.read("/proc/#{parent_pid}/status")
          parent_pid = data.match(/PPid:\s+(\d+)/)[1].to_i
          break if parent_pid == agent_pid
        end

        next parent_pid == agent_pid
      end
    end

    def self.init_storage(node)
      unless node.run_state.key?('agit_storage')
        node.run_state['agit_storage'] = {
          'ssh_wrappers' => [],
          'ssh_auth_sock_dir' => {}
        }
      end
    end

    def self.store_ssh_wrapper(node, path)
      init_storage(node)
      node.run_state['agit_storage']['ssh_wrappers'] << path
    end

    def self.store_ssh_auth_sock_dir(node, path)
      init_storage(node)
      stat = ::File.stat(path)
      unless node.run_state['agit_storage']['ssh_auth_sock_dir'].key?(path)
        node.run_state['agit_storage']['ssh_auth_sock_dir'][path] = {
          'uid' => stat.uid,
          'gid' => stat.gid
        }
      end
    end

    def self.cleanup_ssh_wrappers(node)
      init_storage(node)
      node.run_state['agit_storage']['ssh_wrappers'].each do |path|
        begin
          ::File.delete(path)
        rescue StandardError
          ::Chef::Log.error("Failed to delete file '#{path}'!")
        else
          ::Chef::Log.info("Deleted file '#{path}'.")
        end
      end
    end

    def self.fix_ssh_auth_sock_dirs(node)
      init_storage(node)
      node.run_state['agit_storage']['ssh_auth_sock_dir'].each do |path, stat|
        begin
          ::FileUtils.chown_R(stat['uid'], stat['gid'], path)
        rescue StandardError
          ::Chef::Log.error("Failed to revert '#{path}' owner/group!")
        else
          ::Chef::Log.info("Reverted '#{path}' owner/group.")
        end
      end
    end
  end
end
