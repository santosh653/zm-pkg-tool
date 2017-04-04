#!/usr/bin/perl

use strict;
use warnings;

use Config;
use Cwd;
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path qw/make_path/;
use Getopt::Long;
use IPC::Cmd qw/run can_run/;
use Term::ANSIColor;

my $GLOBAL_PATH_TO_SCRIPT_FILE;
my $GLOBAL_PATH_TO_SCRIPT_DIR;
my $GLOBAL_PATH_TO_TOP;

my %CFG = ();

BEGIN
{
   $GLOBAL_PATH_TO_SCRIPT_FILE = Cwd::abs_path(__FILE__);
   $GLOBAL_PATH_TO_SCRIPT_DIR  = dirname($GLOBAL_PATH_TO_SCRIPT_FILE);
   $GLOBAL_PATH_TO_TOP         = dirname($GLOBAL_PATH_TO_SCRIPT_DIR);
}

sub LoadConfiguration($)
{
   my $args = shift;

   my $cfg_name    = $args->{name};
   my $cmd_hash    = $args->{hash_src};
   my $default_sub = $args->{default_sub};

   my $val;
   my $src;

   if ( !defined $val )
   {
      y/A-Z_/a-z-/ foreach ( my $cmd_name = $cfg_name );

      if ( $cmd_hash && exists $cmd_hash->{$cmd_name} )
      {
         $val = $cmd_hash->{$cmd_name};
         $src = "cmdline";
      }
   }

   if ( !defined $val )
   {
      my $file = "$cmd_hash->{'pkg-path'}/config.pl";
      my $hash = LoadProperties($file)
        if ( -f $file );

      if ( $hash && exists $hash->{$cfg_name} )
      {
         $val = $hash->{$cfg_name};
         $src = "config"
      }
   }

   if ( !defined $val )
   {
      if ($default_sub)
      {
         $val = &$default_sub($cfg_name);
         $src = "default";
      }
   }

   if ( defined $val )
   {
      if ( ref($val) eq "HASH" )
      {
         foreach my $k ( keys %{$val} )
         {
            $CFG{$cfg_name}{$k} = ${$val}{$k};

            printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $k . " => " . ${$val}{$k} );
         }
      }
      elsif ( ref($val) eq "ARRAY" )
      {
         $CFG{$cfg_name} = $val;

         printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", "(" . join( ",", @{ $CFG{$cfg_name} } ) . ")" );
      }
      else
      {
         $CFG{$cfg_name} = $val;

         printf( " %-25s: %-17s : %s\n", $cfg_name, $cmd_hash ? $src : "detected", $val );
      }
   }
}


sub Die($;$)
{
   my $msg  = shift;
   my $info = shift || "";
   my $err  = "$!";

   print "\n";
   print "\n";
   print "=========================================================================================================\n";
   print color('red') . "FAILURE MSG" . color('reset') . " : $msg\n";
   print color('red') . "SYSTEM ERR " . color('reset') . " : $err\n"  if ($err);
   print color('red') . "EXTRA INFO " . color('reset') . " : $info\n" if ($info);
   print "\n";
   print "=========================================================================================================\n";
   print color('red');
   print "--Stack Trace--\n";
   my $i = 1;

   while ( ( my @call_details = ( caller( $i++ ) ) ) )
   {
      print $call_details[1] . ":" . $call_details[2] . " called from " . $call_details[3] . "\n";
   }
   print color('reset');
   print "\n";
   print "=========================================================================================================\n";

   die "END";
}


sub LoadProperties($)
{
   my $f = shift;

   my $x = SlurpFile($f);

   my @cfg_kvs =
     map { $_ =~ s/^\s+|\s+$//g; $_ }    # trim
     map { split( /=/, $_, 2 ) }         # split around =
     map { $_ =~ s/#.*$//g; $_ }         # strip comments
     grep { $_ !~ /^\s*#/ }              # ignore comments
     grep { $_ !~ /^\s*$/ }              # ignore empty lines
     @$x;

   my %ret_hash = ();
   for ( my $e = 0 ; $e < scalar @cfg_kvs ; $e += 2 )
   {
      my $probe_key = $cfg_kvs[$e];
      my $probe_val = $cfg_kvs[ $e + 1 ];

      if ( $probe_key =~ /^%(.*)/ )
      {
         my @val_kv_pair = split( /=/, $probe_val, 2 );

         $ret_hash{$1}{ $val_kv_pair[0] } = $val_kv_pair[1];
      }
      else
      {
         $ret_hash{$probe_key} = $probe_val;
      }
   }

   return \%ret_hash;
}


sub SlurpFile($)
{
   my $f = shift;

   open( FD, "<", "$f" ) || Die( "In open for read", "file='$f'" );

   chomp( my @x = <FD> );
   close(FD);

   return \@x;
}

sub System(@)
{
   my $cmd_str = "@_";

   print color('green') . "#: pwd=@{[Cwd::getcwd()]}" . color('reset') . "\n";
   print color('green') . "#: $cmd_str" . color('reset') . "\n";

   $! = 0;
   my ( $success, $error_message, $full_buf, $stdout_buf, $stderr_buf ) = run( command => \@_, verbose => 1 );

   Die( "cmd='$cmd_str'", $error_message )
     if ( !$success );

   return { msg => $error_message, out => $stdout_buf, err => $stderr_buf };
}

sub GetOsTag()
{
   if ( -f "/etc/redhat-release" )
   {
      chomp( my $v = `sed -n -e '1{s/[^0-9]*/r/; s/[.].*//; p;}' /etc/redhat-release` );
      return $v;
   }
   elsif ( -f "/etc/lsb-release" )
   {
      chomp( my $v = `sed -n -e '/DISTRIB_RELEASE/{s/.*=/u/; s/[.].*//; p;}' /etc/lsb-release` );
      return $v;
   }
   else
   {
      Die("Unknown OS");
   }
}

sub Init()
{
   my %cmd_hash = ();

   my @cmd_args = (
      { name => "PKG_PATH",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not unspecfied"); }, },
      { name => "PKG_TYPE",         type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return "all"; }, },
      { name => "PKG_RELEASE",      type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_VERSION",      type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_SUMMARY",      type => "=s",  hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_INSTALL_LIST", type => "=s@", hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
      { name => "PKG_DEPENDS_LIST", type => "=s@", hash_src => \%cmd_hash, default_sub => sub { return Die("@_ not specified"); }, },
   );

   {
      my @cmd_opts =
        map { $_->{opt} =~ y/A-Z_/a-z-/; $_; }    # convert the opt named to lowercase to make command line options
        map { { opt => $_->{name}, opt_s => $_->{type} } }    # create a new hash with keys opt, opt_s
        grep { $_->{type} }                                   # get only names which have a valid type
        @cmd_args;

      my $help_func = sub {
         print "Usage: $0 <options>\n";
         print "Supported options: \n";
         print "   --" . "$_->{opt}$_->{opt_s}\n" foreach (@cmd_opts);
         exit(0);
      };

      if ( !GetOptions( \%cmd_hash, ( map { $_->{opt} . $_->{opt_s} } @cmd_opts ), help => $help_func ) )
      {
         print Die("wrong commandline options, use --help");
      }
   }

   print "=========================================================================================================\n";
   LoadConfiguration($_) foreach (@cmd_args);
   print "=========================================================================================================\n";
}

sub Build()
{
   if ( my $pkg_name = basename( $CFG{PKG_PATH} ) )
   {
      System( "rm -f 'bld/dist/${pkg_name}'_*" );
      System( "rm",    "-rf", "bld/tmp/$pkg_name/" );
      System( "mkdir", "-p",  "bld/tmp/$pkg_name/" );
      System( "mkdir", "-p",  "bld/dist/" );

      if ( -f "/etc/redhat-release" )
      {
         System( "cp", "-a", "$GLOBAL_PATH_TO_SCRIPT_DIR/default-template/rpm", "bld/tmp/$pkg_name/" );
         System( "cp", "-a", "$CFG{PKG_PATH}/rpm", "bld/tmp/$pkg_name/SPECS" ) if ( -d "$CFG{PKG_PATH}/rpm" );
      }
      elsif ( -f "/etc/lsb-release" )
      {
         System( "cp", "-a", "$GLOBAL_PATH_TO_SCRIPT_DIR/default-template/debian", "bld/tmp/$pkg_name/" );
         System( "cp", "-a", "$CFG{PKG_PATH}/debian", "bld/tmp/$pkg_name/" ) if ( -d "$CFG{PKG_PATH}/debian" );
      }
      else
      {
         Die("Unknown OS");
      }

      find(
         {
            wanted => sub {
               my $tpl_file = $_;
               if ( -f $tpl_file && $tpl_file =~ /[.]in$/ )
               {
                  s/[.]in$// for ( my $new_file = $tpl_file );

                  open( FDr, "<", "$tpl_file" );
                  open( FDw, ">", "$new_file" );

                  while ( my $line = <FDr> )
                  {
                     {
                        my $pkg_install_list =
                          ( $tpl_file =~ /install[.]in/ )
                          ? join( "\n", map { $_ =~ s,^/,,; $_ } @{ $CFG{PKG_INSTALL_LIST} } )
                          : join( "\n", @{ $CFG{PKG_INSTALL_LIST} } );

                        $line =~ s/[@][@]PKG_INSTALL[@][@]/$pkg_install_list/g;
                     }

                     $line =~ s/[@][@]PKG_NAME[@][@]/$pkg_name/g;
                     $line =~ s/[@][@]PKG_RELEASE[@][@]/$CFG{PKG_RELEASE}.@{[GetOsTag()]}/g;
                     $line =~ s/[@][@]PKG_VERSION[@][@]/$CFG{PKG_VERSION}/g;
                     $line =~ s/[@][@]PKG_SUMMARY[@][@]/$CFG{PKG_SUMMARY}/g;
                     $line =~ s/[@][@]PKG_DEPENDS[@][@]/@{[join(",",@{$CFG{PKG_DEPENDS_LIST}})]}/g;

                     print FDw $line;
                  }

                  close(FDr);
                  close(FDw);

                  unlink($tpl_file);
               }
            },
         },
         "bld/tmp/$pkg_name"
      );

      System("make -f '$CFG{PKG_PATH}/Makefile' 'PKG_NAME=$pkg_name' 'PKG_STAGE_DIR=bld/stage/$pkg_name' stage")
         if ( -f "$CFG{PKG_PATH}/Makefile" );

      if ( -f "/etc/redhat-release" )
      {
         my $CWD = getcwd();

	 System("mkdir -p 'bld/tmp/$pkg_name/BUILDROOT/'");
	 System("cp -a -t 'bld/tmp/$pkg_name/BUILDROOT/' 'bld/stage/$pkg_name/'*");
         System("rpmbuild -v --define '_topdir $CWD/bld/tmp/$pkg_name' '--buildroot=$CWD/bld/tmp/$pkg_name/BUILDROOT/' -ba 'bld/tmp/$pkg_name/rpm'/1.spec");

         print "\n\n";
         print "=========================================================================================================\n";
         System("mv -v 'bld/tmp/${pkg_name}/SRPMS/'*.rpm 'bld/tmp/${pkg_name}/RPMS'/*/*.rpm bld/dist/");
         print "=========================================================================================================\n";
      }
      elsif ( -f "/etc/lsb-release" )
      {
         System("cp -a -t 'bld/tmp/$pkg_name/' 'bld/stage/$pkg_name'/*");
         System("cd 'bld/tmp/$pkg_name' && dpkg-buildpackage");

         print "\n\n";
         print "=========================================================================================================\n";
         System("mv -v 'bld/tmp/${pkg_name}'_*.* bld/dist/");
         print "=========================================================================================================\n";
      }
      else
      {
         Die("Unknown OS");
      }
   }
}


sub main()
{
   Init();
   Build();
}

main();
