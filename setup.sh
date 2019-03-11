
# set some environment variables to help use this software
export PERL5LIB=$PWD/perl:$PERL5LIB
export PATH=$PWD:$PATH

# make perl assume UTF8 arguments
# http://blog.thewebsitepeople.org/2012/06/perl-default-to-utf-8-encoding/
export PERL5OPT=-CA
