::Chef.event_handler do
  on :run_completed do |node|
    ::ChefCookbook::AgitHelper.cleanup_ssh_wrappers(node)
    ::ChefCookbook::AgitHelper.fix_ssh_auth_sock_dirs(node)
  end
end
