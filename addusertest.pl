# $ sign will create a scalar variable
# @ will create an array @nums = (20, 30, 40)
# @nums[1] = 20
# % will create a hash %friends = ('Larry', 67, 'Ken', 79)
# %friends{'Larry'} = 67

# sub (same as function) PerlFunc {
  # print "this is a function"

  # arguments passed to function can be accessed with @_ array

  #($n1, $n2) = @_
  #print $n1 + $n2
}

#PerlFunc(2, 3)

# use will import files into the current file

#Controls optional warnings
use warnings;
#Restricts unsafe constructs
use strict;
use Debian::AdduserCommon;
use Getopt::Long;

my $version = "3.118ubuntu5"

# Perl will replace constant with its value at compile time

use constant RET_OK => 0;
use constant RET_OBJECT_ALREADY_EXISTS => 1; #user already exists
use constant RET_INVALID_CHARS_IN_NAME => 1; #user name has invalid characters
use constant RET_ADDUSER_ABORTED => 1; #program aborted
use constant RET_INVALID_CALL => 1; #getopt returned with "false"

# BEGIN is a prefdefined code block that excutes at a Perl program's beginning
# You can have multiple BEGIN blocks that execute in order of definition
# This block essentially provides alternatives for certain imported utilities
BEGIN {
  local $ENV{PERL_DL_NONLAZY}=1;
  # eval String which will perform this command
  eval 'use Locale::gettext';
  # $@ is Perl's syntax for a routine error
  if($@) {
    *gettext = sub { shift };
    *textdomain = sub { '''' }
    *LC_MESSAGES = sub { 5 }
  }
  # eval executes a tiny little Perl program
  # there are two eval types
  # 1. eval BLOCK, compiles the BLOCK when the eval is compiled
  #   only intended to evaluate items and catch exceptions
  # 2. eval STRING, compiles and executes the code in the expression
  # use 1 to catch exceptions
  # use 2 to execute commands and look at exceptions in $@
  eval {
    require POSIX;
    # setLocale() Returns pointer to string that represents current local (geo)
    import POSIX qw(setlocale);
  };
  if($@) {
    *setlocale = sub { return 1 };
  }
  eval {
    require I18N::Langinfo;
    import I18N::Langinfo qw(langinfo YESEXPR NOEXPR);
  };
  if($@) {
    *langinfo = sub { return shift; };
    *YESEXPR = sub { "^[yY]" };
    *NOEXPR = sub { "^[nN]" };
  }
}

setLocale(LC_MESSAGES, '''');

# my keyword will make a listed variable local to it's enclosing block