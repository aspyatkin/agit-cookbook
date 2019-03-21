require 'chef/exceptions'
require 'chef/log'
require 'chef/provider'
require 'fileutils'
require 'etc'

class Chef
  class Exceptions
    class SafeGitRuntimeError < RuntimeError
    end
  end
end

class Chef
  class Provider
    class SafeGit < ::Chef::Provider
      def whyrun_supported?
        true
      end

      def load_current_resource
        @cur_resource ||= ::Chef::Resource::SafeGit.new(new_resource.name)
        d = find_current_metadata

        @cur_resource.repository(d[:repository]) if d.key?(:repository)
        @cur_resource.branch(d[:branch]) if d.key?(:branch)

        @cur_resource
      end

      def define_resource_requirements
        requirements.assert(:update) do |a|
          dirname = ::File.dirname(@new_resource.destination)
          a.assertion { ::File.directory?(dirname) }
          a.whyrun("Directory #{dirname} does not exist, this run will fail "\
                   'unless it has been previously created. Assuming it would '\
                   'have been created.')
          a.failure_message(
            ::Chef::Exceptions::MissingParentDirectory,
            "Cannot clone #{@new_resource} to #{@new_resource.destination}, "\
            "the enclosing directory #{dirname} does not exist"
          )
        end

        requirements.assert(:all_actions) do |a|
          a.assertion { @new_resource.branch !~ /^origin\// }
          a.failure_message(
            ::Chef::Exceptions::InvalidRemoteGitReference,
            'Deploying remote branches is not supported. '\
            'Specify the remote branch as a local branch for '\
            'the git repository you are deploying from '\
            "(ie: '#{@new_resource.branch.gsub('origin/', '')}' rather "\
            "than '#{@new_resource.branch}')."
          )
        end

        requirements.assert(:update) do |a|
          if @cur_resource.repository
            a.assertion { @cur_resource.repository == @new_resource.repository }
            a.whyrun("Git repository at #{new_resource.destination} has "\
                     'different origin url. Assuming it would have matched '\
                     'the specified value.')
            a.failure_message(
              ::Chef::Exceptions::SafeGitRuntimeError,
              "Cannot clone #{@new_resource} to #{@new_resource.destination}, "\
              'another git repository is already located here'
            )
          end
        end

        requirements.assert(:update) do |a|
          a.assertion { branch_exists? }
          a.whyrun('Git remote reference should be present. Assuming it would '\
                   'have been created.')
          a.failure_message(
            ::Chef::Exceptions::SafeGitRuntimeError,
            "Cannot checkout #{@new_resource} to "\
            "#{@new_resource.destination}, remote reference "\
            "#{@new_resource.branch} does not exist"
          )
        end
      end

      def action_update
        if destination_non_existent_or_empty?
          git_clone
        else
          git_fetch
          if @cur_resource.branch != @new_resource.branch
            try_checkout
          else
            try_update
          end
        end
      end

      private

      def try_checkout
        if repository_dirty?
          raise ::Chef::Exceptions::SafeGitRuntimeError,
                "Repository #{@new_resource} is dirty"
        end

        if commits_ahead > 0
          raise ::Chef::Exceptions::SafeGitRuntimeError,
                "Local branch #{@new_resource.branch} of "\
                "#{@new_resource} is #{commits_ahead} commit(s) ahead "\
                'remote. Please push your changes'
        else
          git_checkout
        end
      end

      def try_update
        git_pull if repository_clean? && \
                    commits_ahead.zero? && \
                    commits_behind > 0
      end

      def cwd
        @new_resource.destination
      end

      def find_current_metadata
        r = {}
        ::Chef::Log.debug(
          "#{@new_resource} finding current git repository metadata"
        )
        if ::File.exist?(::File.join(cwd, '.git'))
          r[:repository] = shell_out!('git config --get remote.origin.url',
                                      cwd: cwd, returns: [0, 1]).stdout.strip
          r[:branch] = shell_out!('git rev-parse --abbrev-ref HEAD',
                                  cwd: cwd, returns: [0, 128]).stdout.strip
        end
        r
      end

      def destination_non_existent_or_empty?
        !::File.exist?(@new_resource.destination) ||
          ::Dir.entries(@new_resource.destination).sort == ['.', '..']
      end

      def run_options(run_opts = {})
        env = {}
        if @new_resource.user
          run_opts[:user] = @new_resource.user
          env['HOME'] = \
            begin
              ::Etc.getpwnam(@new_resource.user).dir
            rescue ArgumentError
              raise ::Chef::Exceptions::User,
                    'Could not determine HOME for specified user '\
                    "#{@new_resource.user} for resource #{@new_resource.name}"
            end
        end
        run_opts[:group] = @new_resource.group if @new_resource.group
        env['GIT_SSH'] = @new_resource.ssh_wrapper if @new_resource.ssh_wrapper
        run_opts[:log_tag] = @new_resource.to_s
        run_opts[:timeout] = @new_resource.timeout if @new_resource.timeout
        run_opts[:environment] = env unless env.empty?
        run_opts
      end

      def git_clone
        lbl = "clone from #{@new_resource.repository} into "\
              "#{@new_resource.destination}"
        converge_by(lbl) do
          args = []
          if @new_resource.branch != 'master'
            args << "-b #{@new_resource.branch}"
          end
          ::Chef::Log.info(
            "#{@new_resource} cloning repo #{@new_resource.repository} to "\
            "#{@new_resource.destination}"
          )
          cmd = "git clone #{args.join(' ')} \"#{@new_resource.repository}\" "\
                "\"#{@new_resource.destination}\""
          shell_out!(cmd, run_options)
        end
      end

      def git_fetch
        cmd = 'git fetch --all'
        shell_out!(cmd, run_options(cwd: @new_resource.destination))
      end

      def git_checkout
        lbl = "checkout branch #{@new_resource.branch} on "\
              "#{@new_resource.repository} into #{@new_resource.destination}"
        converge_by(lbl) do
          cmd = "git checkout #{@new_resource.branch}"
          shell_out!(cmd, run_options(cwd: @new_resource.destination))
        end
      end

      def git_pull
        lbl = "pull #{@new_resource.repository} to #{@new_resource.destination}"
        converge_by(lbl) do
          cmd = 'git pull --rebase'
          shell_out!(cmd, run_options(cwd: @new_resource.destination))
        end
      end

      def branch_exists?
        ::Chef::Log.debug("#{@new_resource} resolving remote reference")
        cmd = "git ls-remote \"#{@new_resource.repository}\" "\
              "\"#{new_resource.branch}*\""
        @resolved_refs = shell_out!(cmd, run_options).stdout
        !@resolved_refs.split('\n').map { |line| line.split('\t') }.empty?
      end

      def local_branch
        cmd = 'git rev-parse --abbrev-ref HEAD'
        shell_out!(cmd, run_options(cwd: cwd)).stdout.strip
      end

      def remote_branch
        cmd = 'git rev-parse --abbrev-ref --symbolic-full-name @{u}'
        shell_out!(cmd, run_options(cwd: cwd)).stdout.strip
      end

      def repository_status
        cmd = 'git status --porcelain'
        shell_out!(cmd, run_options(cwd: cwd)).stdout
      end

      def repository_clean?
        repository_status.empty?
      end

      def repository_dirty?
        !repository_status.empty?
      end

      def local_remote_diff_count
        cmd = 'git rev-list --left-right --count ' \
              "#{local_branch}...#{remote_branch}"
        shell_out!(cmd, run_options(cwd: cwd)).stdout.strip.split('\t')
      end

      def commits_ahead
        local_remote_diff_count[0].to_i
      end

      def commits_behind
        local_remote_diff_count[1].to_i
      end
    end
  end
end
