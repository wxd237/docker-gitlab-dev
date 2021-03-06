FROM ubuntu
MAINTAINER wxd237@gmail.com

####========================================
####1. Packages / Dependencies 
RUN sed -i '/deb-src/d' /etc/apt/sources.list
RUN sed -i 's/archive.ubuntu.com/mirrors.163.com/g'  /etc/apt/sources.list
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y sudo  vim vim-rails
RUN update-alternatives --set editor /usr/bin/vim.basic
RUN apt-get install -y git-core

####========================================
####2. Ruby
RUN apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev curl openssh-server redis-server checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev libicu-dev logrotate python-docutils pkg-config cmake nodejs
RUN mkdir /tmp/ruby && cd /tmp/ruby
RUN cd /tmp/ruby && curl -L --progress http://ruby.taobao.org/mirrors/ruby/ruby-2.1.6.tar.gz | tar xz
RUN cd /tmp/ruby/ruby-2.1.6 && ./configure --disable-install-rdoc
RUN cd /tmp/ruby/ruby-2.1.6 && make install
RUN gem sources --remove https://rubygems.org/
RUN  gem sources -a https://ruby.taobao.org/
RUN gem install bundler --no-ri --no-rdoc
####========================================
####3. System Users
RUN adduser --disabled-login --gecos 'GitLab' git
####========================================
####4. Database
RUN  apt-get install -y postgresql postgresql-client libpq-dev
RUN apt-get install -y   redis-server
RUN apt-get install -y  mariadb-server mariadb-client libmariadbclient-dev
RUN apt-get install -y aptitude

#RUN mysql_secure_installation
#redis set
RUN cp /etc/redis/redis.conf /etc/redis/redis.conf.orig
RUN sed 's/^port .*/port 0/' /etc/redis/redis.conf.orig | sudo tee /etc/redis/redis.conf
RUN echo 'unixsocket /var/run/redis/redis.sock' | sudo tee -a /etc/redis/redis.conf
RUN echo 'unixsocketperm 770' | sudo tee -a /etc/redis/redis.conf
RUN mkdir /var/run/redis
RUN chown redis:redis /var/run/redis
RUN  chmod 755 /var/run/redis
RUN usermod -aG redis git

WORKDIR /home/git
RUN sudo -u git -H git clone https://github.com/wxd237/gitlabhq-i18n-cn -b master gitlab
WORKDIR /home/git/gitlab
RUN sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml

RUN sudo mkdir -p log tmp/pids   tmp/sockets/   public/uploads
RUN sudo chown -R git log/  
RUN sudo chown -R git tmp/
RUN sudo chmod -R u+rwX,go-w log/
RUN sudo chmod -R u+rwX tmp/
RUN sudo -u git -H mkdir /home/git/gitlab-satellites
RUN sudo chmod u+rwx,g=rx,o-rwx /home/git/gitlab-satellites
RUN sudo chmod -R u+rwX tmp/pids/
RUN sudo chmod -R u+rwX tmp/sockets/
RUN sudo chmod -R u+rwX  public/uploads
RUN sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb
## edit unicorn.rb
RUN sudo -u git -H cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb
RUN sudo -u git -H git config --global core.autocrlf input
RUN sudo -u git -H cp config/resque.yml.example config/resque.yml
## Change the Redis socket path if you are not using the default Debian / Ubuntu configuration
#RUN sudo -u git -H editor config/resque.yml  
# postgre sudo -u git cp config/database.yml.postgresql config/database.yml
RUN sudo -u git cp config/database.yml.mysql config/database.yml
## edit config/database.yml
RUN sudo -u git -H chmod o-rwx config/database.yml
RUN sudo -u git -H sed -i 's/rubygems.org/ruby.taobao.org/g' Gemfile
RUN sudo -u git -H bundle install --deployment --without development test postgres aws kerberos
RUN apt-get install -y nginx
RUN sudo cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
RUN sudo ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
RUN unlink /etc/nginx/sites-enabled/default

##Install GitLab Shell
RUN sudo -u git -H bundle exec rake gitlab:shell:install[v2.6.3] REDIS_URL=unix:/var/run/redis/redis.sock RAILS_ENV=production


RUN cp lib/support/init.d/gitlab /etc/init.d/gitlab
RUN sudo update-rc.d gitlab defaults 21
RUN cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab
#RUN sudo -u git -H echo yes|bundle exec rake gitlab:setup RAILS_ENV=production









RUN mkdir  /app
COPY init /app/init
RUN chmod +x /app/init
#RUN chmod 755 /app/setup/install
#RUN /app/setup/install

#COPY assets/config/ /app/setup/config/
#COPY assets/init /app/init
#RUN chmod 755 /app/init

EXPOSE 22
EXPOSE 80
EXPOSE 8080
#EXPOSE 443

#VOLUME ["/home/git/data"]
#VOLUME ["/var/log/gitlab"]

WORKDIR /home/git/gitlab
ENTRYPOINT ["/app/init"]
CMD ["app:start"]
