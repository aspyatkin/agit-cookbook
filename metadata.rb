name 'agit'
maintainer 'Alexander Pyatkin'
maintainer_email 'aspyatkin@gmail.com'
license 'MIT'
version '0.1.0'
description 'A safer replacement for Chef git resource'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))

supports 'ubuntu'

provides :agit

gem 'git_clone_url'
