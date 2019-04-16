name 'agit'
maintainer 'Alexander Pyatkin'
maintainer_email 'aspyatkin@gmail.com'
license 'MIT'
version '0.1.2'
description 'A safer replacement for Chef git resource'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))

supports 'ubuntu'

provides :agit

gem 'git_clone_url'

scm_url = 'https://github.com/aspyatkin/agit-cookbook'
source_url scm_url if respond_to?(:source_url)
issues_url "#{scm_url}/issues" if respond_to?(:issues_url)
