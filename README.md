# agit cookbook

A safer replacement for Chef git resource.

## Concept

Chef git resource is rather user-unfriendly. It is notoriously difficult to find a combination of `checkout_branch`, `enable_checkout` and `revision` so that all works perfectly.

There are several major improvements introduced by this cookbook.

Firstly, only one attribute is used to control a repository's `HEAD` (current branch).

Secondly, changes in a local copy of the repository are respected. The current branch will not be changed if the repository's state is "dirty". Unlike Chef git resource `:sync` action, uncommited changes will not be reset.

Thirdly, SSH agent forwarding is fully supported.

## Usage

```
agit '/opt/hello' do
  repository 'git@github.com:acme/hello.git'
  branch 'develop'
  user 'vagrant'
  group 'vagrant'
  action :update
end
```

## Notes

Regarding SSH agent forwarding it is important to include `agit::cleanup` recipe into a node's run list. During Chef client run `agit` alters the permissions of the forwarded SSH agent socket (the value is stored in `SSH_AUTH_SOCK` environment variable). Cleanup recipe restores those permissions.

## License
MIT @ [Alexander Pyatkin](https://github.com/aspyatkin)
