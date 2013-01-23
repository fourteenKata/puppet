#! /usr/bin/env ruby
require 'spec_helper'

provider_class = Puppet::Type.type(:package).provider(:rpm)

describe provider_class do
  subject { provider_class }

  let (:packages) do
    <<-RPM_OUTPUT
    cracklib-dicts 0 2.8.9 3.3 x86_64
    basesystem 0 8.0 5.1.1.el5.centos noarch
    chkconfig 0 1.3.30.2 2.el5 x86_64
    myresource 0 1.2.3.4 5.el4 noarch
    RPM_OUTPUT
  end

  let(:resource) do
    Puppet::Type.type(:package).new(
      :name     => 'myresource',
      :ensure   => :installed
    )
  end

  let(:provider) do
    provider = provider_class.new
    provider.resource = resource
    provider
  end

  before(:each) do
    Puppet::Util.stubs(:which).with("rpm").returns("/bin/rpm")
    subject.stubs(:which).with("rpm").returns("/bin/rpm")
    subject.instance_variable_set("@current_version", nil)
    Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "--version"]).returns(rpm_version).at_most_once
  end

  describe "self.instances" do
    let(:rpm_version) { "RPM version 5.0.0\n" }
    before(:each) do
    end
    describe "with a modern version of RPM" do
      it "should include all the modern flags" do
        Puppet::Type::Package::ProviderRpm.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf '%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n'").yields(packages)

        installed_packages = subject.instances
      end
    end

    describe "with a version of RPM < 4.1" do
      let(:rpm_version) { "RPM version 4.0.2\n" }
      it "should exclude the --nosignature flag" do
        Puppet::Type::Package::ProviderRpm.expects(:execpipe).with("/bin/rpm -qa  --nodigest --qf '%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n'").yields(packages)

        installed_packages = subject.instances
      end
    end

    describe "with a version of RPM < 4.0.2" do
      let(:rpm_version) { "RPM version 3.0.5\n" }
      it "should exclude the --nodigest flag" do
        Puppet::Type::Package::ProviderRpm.expects(:execpipe).with("/bin/rpm -qa   --qf '%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n'").yields(packages)

        installed_packages = subject.instances
      end
    end

    it "returns an array of packages" do
      Puppet::Type::Package::ProviderRpm.expects(:execpipe).with("/bin/rpm -qa --nosignature --nodigest --qf '%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n'").yields(packages)

      installed_packages = subject.instances

      installed_packages[0].properties.should ==
        {
          :provider => :rpm,
          :name => "cracklib-dicts",
          :epoch => "0",
          :version => "2.8.9",
          :release => "3.3",
          :arch => "x86_64",
          :ensure => "2.8.9-3.3"
        }
      installed_packages[1].properties.should ==
        {
          :provider => :rpm,
          :name => "basesystem",
          :epoch => "0",
          :version => "8.0",
          :release => "5.1.1.el5.centos",
          :arch => "noarch",
          :ensure => "8.0-5.1.1.el5.centos"
        }
      installed_packages[2].properties.should ==
        {
          :provider => :rpm,
          :name => "chkconfig",
          :epoch => "0",
          :version => "1.3.30.2",
          :release => "2.el5",
          :arch => "x86_64",
          :ensure => "1.3.30.2-2.el5"
        }
    end
  end

  describe "#uninstall" do
    let(:resource) do
      Puppet::Type.type(:package).new(
        :name     => 'myresource',
        :ensure   => :installed
      )
    end

    describe "on a modern RPM" do
      before(:each) do 
        Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "-q",  "myresource", '--nosignature', '--nodigest', "--qf", "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"]).returns("myresource 0 1.2.3.4 5.el4 noarch\n")
      end

      let(:rpm_version) { "RPM version 4.10.0\n" }

      it "should include the architecture in the package name" do
        Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "-e", 'myresource-1.2.3.4-5.el4.noarch']).returns('').at_most_once
        provider.uninstall
      end
    end

    describe "on an ancient RPM" do
      before(:each) do 
        Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "-q",  "myresource", '', '', "--qf", "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"]).returns("myresource 0 1.2.3.4 5.el4 noarch\n")
      end

      let(:rpm_version) { "RPM version 3.0.6\n" }

      it "should exclude the architecture from the package name" do
        Puppet::Type::Package::ProviderRpm.expects(:execute).with(["/bin/rpm", "-e", 'myresource-1.2.3.4-5.el4']).returns('').at_most_once
        provider.uninstall
      end
    end
    
  end
end
