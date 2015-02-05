# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'resolv'

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "trusty-server-cloudimg-amd64-vagrant-disk1"
  config.vm.box_url = 'https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box'
  config.vm.network "private_network", ip: Resolv.getaddress("ad-test.pontiki.dev")
  config.ssh.forward_agent = true

  config.vm.provision "ansible" do |a|
    a.playbook = 'provisioning/playbook.yml'
  end
end
