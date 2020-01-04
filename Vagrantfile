# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'date'
require 'yaml'

config = YAML.load_file('config.yaml')

Dir.mkdir 'tmp' unless File.exists?('tmp')
Dir.mkdir 'group_vars' unless File.exists?('group_vars')

now = DateTime.now.strftime("%Y%m%d%H%M%S")
master = "tmp/master_#{now}"
worker = "tmp/worker_#{now}"

Vagrant.configure("2") do |vagrant|

  hostsEntries = []
  etcd_cluster = []

  # Masters
  File.open(master, 'w') { |f| f.puts '[master]' }
  config['master']['count'].times do |i|
    name = create_node(vagrant, config, i, 'master')
    File.open(master, 'a') { |f| f.puts "#{name} ansible_connection=local" }

    hostsEntries << "#{ip} #{name}"
    etcd_cluster << "#{name}=http://#{name}:2380"
  end

  File.open('group_vars/master.yaml', 'w') { |f| f.puts "datastoreEndpoint: #{etcd_cluster.join(',')}" }

  provision(vagrant, master)

  # Workers
  File.open(worker, 'w') { |f| f.puts '[worker]' }
  config['worker']['count'].times do |i|
    name = create_node(vagrant, config, i, 'worker')
    File.open(worker, 'a') { |f| f.puts "#{name} ansible_connection=local" }
    
    hostsEntries << "#{ip} #{name}"
  end

  File.open('group_vars/all.yaml', 'w') { |f| f.puts({'hosts' => hostsEntries}.to_yaml) }

  provision(vagrant, worker)
end 

def create_node(vagrant, config, count, type='master')

  name =  "#{type}%02d" % (count+1)
  ipSplit = config["#{type}"]['specs']['eth1'].split('.')
  ip = "#{ipSplit[0]}.#{ipSplit[1]}.#{ipSplit[2]}.#{(ipSplit[3].to_i-1)+(count+1)}"

  vagrant.vm.define name do |node|
    node.vm.box = config["#{type}"]['specs']['box']
    node.vm.hostname = name
    node.vm.network :private_network, ip: ip
    node.vm.boot_timeout = 600
    node.vbguest.auto_update = false

    node.vm.provider "virtualbox" do |v|
      v.customize ["modifyvm", :id, "--memory", config["#{type}"]['specs']['mem']]
      v.customize ["modifyvm", :id, "--cpus",   config["#{type}"]['specs']['cpu']]
    end
  end

  return name

end

def provision(vagrant, inventory)
  vagrant.vm.provision "ansible_local" do |ansible|
    ansible.become = true
    ansible.playbook = "playbook.yaml"
    ansible.inventory_path = inventory
    ansible.install_mode = "pip"
  end
end
