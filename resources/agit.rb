require 'etc'
require 'fileutils'
require 'git_clone_url'

resource_name :agit

property :destination, String, name_property: true
property :repository, String, required: true
property :branch, String, required: true
property :user, String, required: true
property :group, String, required: true
property :mode, [String, Integer], default: 0o755
property :timeout, Integer, default: 600

default_action :update

action :update do
  parsed_url = ::GitCloneUrl.parse(new_resource.repository)
  ssh_required = parsed_url.is_a?(::URI::SshGit::Generic)

  ssh_wrapper_file_path = nil

  ruby_block "create SSH wrapper for #{new_resource.repository} at "\
             "#{new_resource.destination}" do
    block do
      uid = ::Etc.getpwnam(new_resource.user).uid
      gid = ::Etc.getgrnam(new_resource.group).gid

      ssh_auth_sock = ::ChefCookbook::AgitHelper.ssh_auth_sock
      if ssh_auth_sock.nil?
        ::Chef::Log.warn('$SSH_AUTH_SOCK is not available!')
        next
      end

      ssh_auth_sock_dir = ::File.dirname(ssh_auth_sock)
      ::ChefCookbook::AgitHelper.store_ssh_auth_sock_dir(node,
                                                         ssh_auth_sock_dir)
      ::FileUtils.chown_R(uid, gid, ssh_auth_sock_dir)

      ssh_wrapper_file = ::Tempfile.new('ssh_wrapper')
      ::ObjectSpace.undefine_finalizer(ssh_wrapper_file)
      ssh_wrapper_file_path = ssh_wrapper_file.path

      ::File.chmod(0o700, ssh_wrapper_file.path)
      ::File.chown(uid, gid, ssh_wrapper_file.path)
      ssh_wrapper_file.write("#!/bin/bash\nSSH_AUTH_SOCK=#{ssh_auth_sock} "\
                             'ssh $1 $2')
      ssh_wrapper_file.close

      ::ChefCookbook::AgitHelper.store_ssh_wrapper(node, ssh_wrapper_file_path)
    end
    action ssh_required ? :run : :nothing
  end

  directory new_resource.destination do
    owner new_resource.user
    group new_resource.group
    mode new_resource.mode
    recursive true
    action :create
  end

  safegit new_resource.destination do
    ssh_wrapper(lazy { ssh_wrapper_file_path }) if ssh_required
    repository new_resource.repository
    branch new_resource.branch
    user new_resource.user
    group new_resource.group
    timeout new_resource.timeout
    action :update
  end
end
