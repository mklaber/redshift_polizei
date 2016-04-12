FROM ruby

ADD . /apps/polizei

WORKDIR /apps/polizei
RUN bundle install

EXPOSE 9999
EXPOSE 3030
CMD ["/usr/local/bundle/bin/shotgun", "--host", "0.0.0.0"]
