#
# Cookbook Name:: 3a-classic
# Recipe:: default
#
# Copyright 2016, 3a-classic
#
# All rights reserved - Do Not Redistribute
#
#

node['package']['names'].each do |pac|
  package pac
end

user node['deploy']['user']['name'] do
  comment "#{node['deploy']['user']['name']} user"
  uid node['deploy']['user']['id']
  home node['deploy']['user']['home']
  shell node['deploy']['user']['shell']
end

directory "#{node['deploy']['user']['home']}" do
  owner node['deploy']['user']['name']
  group node['deploy']['user']['name']
  mode '755'
end

directory "#{node['deploy']['user']['home']}/.ssh" do
  owner node['deploy']['user']['name']
  group node['deploy']['user']['name']
  mode '711'
end

cookbook_file "#{node['deploy']['user']['home']}/.ssh/authorized_keys" do
  source 'authorized_keys'
  owner node['deploy']['user']['name']
  group node['deploy']['user']['name']
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
  members node['deploy']['user']['name']
  append true
  notifies  :restart , 'service[docker]', :immediately
end

ruby_block "source_go_env" do
  block do
    ENV['GOROOT'] = "#{node['deploy']['user']['home']}/go"
    ENV['GOOS'] = 'linux'
    ENV['GOARCH'] = 'amd64'
    ENV['GOBIN'] = "#{node['deploy']['user']['home']}/go/bin"
    ENV['GOPATH'] = "#{node['deploy']['user']['home']}/go/plugins"
  end
  action :run
end

template '/etc/profile.d/go.sh' do
  source 'go.sh.erb'
end

execute 'install golang' do
  command "wget #{node['golang']['src']['url']} -P #{node['deploy']['user']['home']} &&
           tar zxvfk #{node['deploy']['user']['home']}/#{node['golang']['src']['name']} -C #{node['deploy']['user']['home']} &&
           rm -f #{node['deploy']['user']['home']}/#{node['golang']['src']['name']}"
  creates  "#{node['deploy']['user']['home']}/go"
  notifies :create, "ruby_block[source_go_env]", :immediately
end

directory "#{node['deploy']['user']['home']}/go/plugins" do
  owner node['deploy']['user']['name']
  group node['deploy']['user']['name']
  mode '755'
end

execute 'go get gb and goimport' do
  command "#{node['deploy']['user']['home']}/go/bin/go get github.com/constabulary/gb/... &&
          #{node['deploy']['user']['home']}/go/bin/go get golang.org/x/tools/cmd/goimports"
  creates "#{node['deploy']['user']['home']}/go/plugins/src/github.com/constabulary/gb"
end

link '/usr/local/bin/gb-vendor' do
  to "#{node['deploy']['user']['home']}/go/bin/gb-vendor"
  link_type :symbolic
end


directory "#{node['deploy']['user']['home']}/nginx-proxy-vhost.d" do
  owner node['deploy']['user']['name']
  group node['deploy']['user']['name']
  mode '755'
end

cookbook_file "#{node['deploy']['user']['home']}/nginx-proxy-vhost.d/default_location" do
  source 'default_location'
  owner node['deploy']['user']['name']
  group node['deploy']['user']['name']
  mode '755'
end

execute 'nginx-proxy docker start' do
  command "docker run -d -t \
           -v /var/run/docker.sock:/tmp/docker.sock:ro \
           -v #{node['deploy']['user']['home']}/nginx-proxy-vhost.d:/etc/nginx/vhost.d/ \
           --name nginx-proxy \
           --hostname nginx-proxy \
           -p 80:80 \
           -p 443:443 \
           jwilder/nginx-proxy"
  not_if 'docker ps -a | grep nginx-proxy'
end


node['git']['branchs'].each do |br|
  git "#{node['deploy']['user']['home']}/#{br}" do
    repository node['git']['url']
    revision br
    user node['deploy']['user']['name']
    group node['deploy']['user']['name']
  end

  execute "gb vendor restore in #{br}" do
    command "#{node['deploy']['user']['home']}/go/bin/gb vendor restore ./vendor/manifest &&
             #{node['deploy']['user']['home']}/go/bin/gb build"
    cwd "#{node['deploy']['user']['home']}/#{br}"
    creates "#{node['deploy']['user']['home']}/#{br}/vendor/src"
  end

  execute "docker create #{br} mongo volume" do
    command "docker volume create --name #{br}-mongo"
    not_if "docker volume ls | grep #{br}-mongo"
  end
  
  execute "#{br} mongo docker start" do
    command "docker run -d \
             -v #{br}-mongo:/data/db \
             --name #{br}-mongo \
             --hostname #{br}-api-server \
             --expose 80 \
             mongo"
    not_if "docker ps -a | grep #{br}-mongo"
  end

  execute "#{br} docker start" do
    command "docker run -d -t \
             -v #{node['deploy']['user']['home']}/#{br}:/go/src \
             --net container:#{br}-mongo \
             --ipc container:#{br}-mongo \
             --name #{br}-score-api-server \
             golang:latest \
             bash -c /go/src/bin/3aClassic-linux-amd64"
    not_if "docker ps -a | grep #{br}-score-api-server"
  end
end
