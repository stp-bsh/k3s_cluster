# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
require 'ostruct'

config = YAML.load_file('config.yaml')

Dir.mkdir 'tmp' unless File.exists?('tmp')

Vagrant.configure("2") do |vagrant|
  now = DateTime.now.strftime("%Y%m%d%H%M%S")
  hosts_file = "tmp/hosts"
  File.open(hosts_file, 'w')  # Clear the .hosts file

  # BEGIN: Generate list of host entries
  config['master']['count'].times do |i|
    name, ip = generate_name_and_ip(config['master'], i, 'master')
    File.open(hosts_file, 'a') { |f| f.puts "#{ip} #{name}" }

    # Points k3s.local and etcd.local to master01's IP
    File.open(hosts_file, 'a') { |f| f.puts "#{ip} k3s.local" } if name == 'master01'
    File.open(hosts_file, 'a') { |f| f.puts "#{ip} etcd.local" } if name == 'master01'
  end

  config['worker']['count'].times do |i|
    name, ip = generate_name_and_ip(config['worker'], i, 'worker')
    File.open(hosts_file, 'a') { |f| f.puts "#{ip} #{name}" }
  end

  config['hosts'].each do |host|
    File.open(hosts_file, 'a') { |f| f.puts host }
  end

  # END: Generate list of host entries

  # BEGIN: Create nodes
  config['master']['count'].times do |i|
    create_node(vagrant, config, i, 'master')
  end

  config['worker']['count'].times do |i|
    create_node(vagrant, config, i, 'worker')
  end
  # END: Create nodes
end

def generate_name_and_ip(obj, count, type)
  name  = "#{type}%02d" % (count+1)
  split = obj['specs']['eth1'].split('.')
  ip    = "#{split[0]}.#{split[1]}.#{split[2]}.#{(split[3].to_i-1)+(count+1)}"
  return name, ip
end

def create_node(vagrant, config, count, type='master')
  obj = config[type]
  k3s = config['k3s']
  name, ip = generate_name_and_ip(obj, count, type)

  # Create env file for node
  env_file = "tmp/#{name}"
  File.open(env_file, 'w')  # Clear the node's env file
  File.open(env_file, 'a') do |f|
    f.puts "K3S_NODE_TYPE=#{type}"
    f.puts "K3S_NODE_IP=#{ip}"
    f.puts "K3S_VERSION=#{k3s['version']}"
    f.puts "K3S_TOKEN=#{k3s['token']}"
    f.puts "K3S_DATASTORE_ENDPOINT=#{k3s['datastoreEndpoint']}"
    f.puts "K3S_CLUSTER_NAME=#{k3s['clusterName']}"
    f.puts "K3S_PARAMS=\"#{obj['k3sParams']}\""
  end

  vagrant.vm.define name do |node|
    node.vm.box = obj['specs']['box']
    node.vm.hostname = name
    node.vm.network :private_network, ip: ip
    node.vm.boot_timeout = 600
    node.vbguest.auto_update = false

    node.vm.provider "virtualbox" do |v|
      v.customize ["modifyvm", :id, "--memory", obj['specs']['mem']]
      v.customize ["modifyvm", :id, "--cpus",   obj['specs']['cpu']]
    end

    node.vm.provision "shell", path: 'provision.sh', args: [name, type]
  end

end
