FROM google/cloud-sdk

RUN wget https://releases.hashicorp.com/vagrant/1.9.1/vagrant_1.9.1_x86_64.deb
RUN dpkg -i vagrant_1.9.1_x86_64.deb
RUN vagrant plugin install vagrant-google

RUN apt-get -y update
RUN apt-get -y install ruby
RUN gem install bosh_cli --no-ri --no-rdoc
