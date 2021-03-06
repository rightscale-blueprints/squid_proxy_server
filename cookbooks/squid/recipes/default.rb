# Author:: Matt Ray <matt@opscode.com>
# Cookbook Name:: squid
# Recipe:: default
#
# Copyright 2012, Opscode, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package "squid"

service node['squid']['service_name'] do
  case node['platform']
  when "redhat","centos","scientific","fedora","suse"
    provider Chef::Provider::Service::Redhat
  when "debian","ubuntu"
    provider Chef::Provider::Service::Upstart
  end
  supports :restart => true, :status => true, :reload => true
  action [ :enable, :start ]
end

case node['platform']
when "redhat","centos","scientific","fedora","suse"
  template "/etc/sysconfig/squid" do
    source "redhat/sysconfig/squid.erb"
    notifies :restart, "service[#{node['squid']['service_name']}]", :delayed
    mode "644"
  end
end

if node['squid']['network']
  network = node['squid']['network']
else
  network = node.ipaddress[0,node.ipaddress.rindex(".")]+".0/24"
end
Chef::Log.info "Squid network #{network}"

version = node['squid']['version']
Chef::Log.info "Squid version number (unknown if blank): #{version}"

template "#{node['squid']['config_dir']}/squid.conf" do
  source "squid#{version}.conf.erb"
  notifies :reload, "service[#{node['squid']['service_name']}]"
  mode "644"
end

url_acl = []
begin
  data_bag("squid_urls").each do |bag|
    group = data_bag_item("squid_urls",bag)
    group['urls'].each do |url|
      url_acl.push [group['id'],url]
    end
  end
rescue
  Chef::Log.info "no 'squid_urls' data bag"
end

host_acl = []
begin
  data_bag("squid_hosts").each do |bag|
    group = data_bag_item("squid_hosts",bag)
    group['net'].each do |host|
      host_acl.push [group['id'],group['type'],host]
    end
  end
rescue
  Chef::Log.info "no 'squid_hosts' data bag"
end

acls = []
begin
  data_bag("squid_acls").each do |bag|
    group = data_bag_item("squid_acls",bag)
    group['acl'].each do |acl|
      acls.push [acl[1],group['id'],acl[0]]
    end
  end
rescue
  Chef::Log.info "no 'squid_acls' data bag"
end

template "#{node['squid']['config_dir']}/chef.acl.config" do
  source "chef.acl.config.erb"
  variables(
    :acls => acls,
    :host_acl => host_acl,
    :url_acl => url_acl
    )
  notifies :reload, "service[#{node['squid']['service_name']}]"
end