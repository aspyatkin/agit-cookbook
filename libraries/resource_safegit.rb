require 'chef/resource'

class Chef
  class Resource
    class SafeGit < ::Chef::Resource
      provides :safegit

      def initialize(name, run_context = nil)
        super
        @resource_name = :safegit
        @provider = ::Chef::Provider::SafeGit
        @action = :update
        @allowed_actions = [:update]

        @repository = nil
        @branch = 'master'
        @destination = name
        @user = 'root'
        @group = 'root'
        @ssh_wrapper = nil
        @timeout = 600
      end

      def repository(arg = nil)
        set_or_return(:repository, arg, kind_of: String)
      end

      def branch(arg = nil)
        set_or_return(:branch, arg, kind_of: String)
      end

      def destination(arg = nil)
        set_or_return(:destination, arg, kind_of: String)
      end

      def user(arg = nil)
        set_or_return(:user, arg, kind_of: String)
      end

      def group(arg = nil)
        set_or_return(:group, arg, kind_of: String)
      end

      def ssh_wrapper(arg = nil)
        set_or_return(:ssh_wrapper, arg, kind_of: String)
      end

      def timeout(arg = nil)
        set_or_return(:timeout, arg, kind_of: Integer)
      end
    end
  end
end
