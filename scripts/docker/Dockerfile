FROM bauk/git:full

RUN yum install -y crontabs openssh-clients "perl(Term::ReadKey)" "perl(JSON)" \
 && yum clean -y all


CMD ["/entrypoint.sh"]
COPY ./entrypoint.sh /entrypoint.sh
COPY ./update.sh /update.sh
