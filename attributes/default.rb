default['package']['names'] = %w(vim bzr git tmux htop)


default['deploy']['user']['name'] = 'circle'
default['deploy']['user']['id'] = '1500'
default['deploy']['user']['home'] = "/home/#{default['deploy']['user']['name']}"
default['deploy']['user']['shell'] = "/bin/bash"

default['golang']['version'] = '1.6'
default['golang']['src']['name'] = "go#{default['golang']['version']}.linux-amd64.tar.gz"
default['golang']['src']['url'] = "https://storage.googleapis.com/golang/#{default['golang']['src']['name']}"

default['git']['url'] = 'https://github.com/3a-classic/score-api-server.git'
default['git']['branchs'] = %w(master stage)
