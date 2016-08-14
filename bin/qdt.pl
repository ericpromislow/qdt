#!/usr/bin/env perl

# qdt.pl -- quick-and-dirty templater

package main;

use strict;
use warnings;

use lib "./lib";
use QDT qw/checkErrors parseDoc processOutput removeExtraWhiteSpace/;

if (@ARGV && $ARGV[0] eq "-v") {
    $QDT::verbose = 1;
    shift @ARGV;
}

my $fname = $ARGV[0];
my $text;
$/ = undef;
if ($fname) {
    open my $fh, "<", $fname or die "Can't open $fname for reading: $!";
    $text = <$fh>;
    close $fh;
} else {
    $text = <DATA>;
    close DATA;
}
my $res = parseDoc($text);
checkErrors($res->[1]);
processOutput(removeExtraWhiteSpace($res->[0]));

__DATA__
<%
sub ep {
  my ($name, $default) = @_;
  if (defined $ENV{$name}) {
    return $ENV{$name}
  } elsif (defined $default) {
    return $default;
  } else {
    print STDERR "No value for enviroment var $name\n";
    return "** $name **";
  }
}

%>

spring_profiles: postgresql<% if (ep("LDAP_ENABLED", 0)) { %>
database:
  driverClassName: 'org.\'postgresql.Driver'

  url: jdbc:postgresql://<%= ep("DB_ADDR") %>:<%= ep 'DB_PORT' %>/<%=ep("DB_ENV_DB", "uaa") %>?ssl=true&sslmode=verify-full
<% } else {# LDAP_ENABLED check %>
chuck:
   yambo: no ldap here : <%= $ENV{HOME} %>
<% } # LDAP_ENABLED check %>

oauth:
  clients:
    things: 33

array_here:
   bink: 3
   <% if ($val = ep("LIST", 0)) {
     $val = eval($val);
     if ($@) {
       print STDERR "Error eval'ing var LIST => $val: $@\n";
     } else { %>
   list:
       <% for $x (@$val) { -%>
     - '<%= quoteEscape($x) %>'
       <% } -%>
     <% } # end if error %>
   <% } # end if list %>

 <% if ($val = ep("HASH", 0)) { %>
hash_here:
    bink: 4
    <%
    $val = eval($val);
    if ($@) {
      print STDERR "Error eval'ing var LIST => $val: $@\n";
    } else { %>
    stuff:
      <% while( ($k, $v) = each %$val) { %>
       <%= $k %>: '<%= quoteEscape($v) %>'
      <% } %>
    <% } %>
<% } %>
