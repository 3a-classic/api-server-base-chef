#
# Cookbook Name:: 3a-classic
# Recipe:: default
#
# Copyright 2016, 3a-classic
#
# All rights reserved - Do Not Redistribute
#
#

package 'vim'
package 'bzr'
package 'git'
package 'tmux'
package 'htop'

user 'circle' do
  comment 'circleci user'
  uid 1500
  home '/home/circle'
  shell '/bin/bash'
end

directory '/home/circle/.ssh' do
  owner 'circle'
  group 'circle'
  mode '600'
end

cookbook_file '/home/circle/.ssh/authorized_keys' do
  source 'authorized_keys'
  owner 'circle'
  group 'circle'
  mode '600'
end

service 'docker' do
  supports :start => true, :status => true, :restart => true, :reload => true
end

execute 'install docker' do
  command 'curl -fsSL https://get.docker.com/ | sh'
  creates '/var/lib/docker'
  notifies :start , 'service[docker]', :immediately
end

group 'docker' do
  action :modify
  members 'circle'
  append true
  notifies  :restart , 'service[docker]', :immediately
end

ruby_block "source_go_env" do
  block do
    ENV['GOROOT'] = '/home/circle/go'
    ENV['GOOS'] = 'linux'
    ENV['GOARCH'] = 'amd64'
    ENV['GOBIN'] = '/home/circle/go/bin'
    ENV['GOPATH'] = '/home/circle/go/plugins'
  end
  action :run
end

template '/etc/profile.d/go.sh' do
  source 'go.sh.erb'
end

execute 'install golang' do
  command 'wget https://storage.googleapis.com/golang/go1.6.linux-amd64.tar.gz -P /home/circle/ &&
           tar zxvfk /home/circle/go1.6.linux-amd64.tar.gz -C /home/circle &&
           rm -f /home/circle/go1.6.linux-amd64.tar.gz'
  creates  '/home/circle/go'
  notifies :create, "ruby_block[source_go_env]", :immediately
end

directory '/home/circle/go/plugins' do
  owner 'circle'
  group 'circle'
  mode '755'
end

execute 'go get packages' do
  command '/home/circle/go/bin/go get github.com/peco/peco/cmd/peco
           /home/circle/go/bin/go get github.com/motemen/ghq
           /home/circle/go/bin/go get github.com/maruel/panicparse/cmd/pp
           /home/circle/go/bin/go get -u github.com/nsf/gocode
           /home/circle/go/bin/go get -u github.com/golang/lint/golint
           /home/circle/go/bin/go get golang.org/x/tools/cmd/goimports
           /home/circle/go/bin/go get github.com/constabulary/gb/...'
end

git '/home/circle/pro-api-server' do
  repository 'https://github.com/3a-classic/score-api-server.git'
  revision 'master'
  user 'circle'
  group 'circle'
end

git '/home/circle/sta-api-server' do
  repository 'https://github.com/3a-classic/score-api-server.git'
  revision 'stage'
  user 'circle'
  group 'circle'
end

directory '/home/circle/nginx-proxy-vhost.d' do
  owner 'circle'
  group 'circle'
  mode '755'
end

cookbook_file '/home/circle/nginx-proxy-vhost.d/default_location' do
  source 'default_location'
  owner 'circle'
  group 'circle'
  mode '755'
end

execute 'nginx-proxy docker start' do
  command 'service docker start && docker run -d -t \
           -v /var/run/docker.sock:/tmp/docker.sock:ro \
           -v /home/circle/nginx-proxy-vhost.d:/etc/nginx/vhost.d/ \
           --name nginx-proxy \
           --hostname nginx-proxy \
           -p 80:80 \
           jwilder/nginx-proxy'
  not_if 'docker ps -a | grep nginx-proxy'
end
