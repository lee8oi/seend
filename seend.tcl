namespace eval seend {
########################################################################
# Copyright ©2011 lee8oi@gmail.com
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# http://www.gnu.org/licenses/
#
# Seend v1.8.3 (8-6-11)
# by: <lee8oiAtgmail><lee8oiOnfreenode>
# egghelp forum: http://forum.egghelp.org/viewtopic.php?t=18493
# github link: https://github.com/lee8oi/eggdrop/blob/master/seend.tcl
#
# Original Sseend based on:
# Sseen v0.2.22 by samu (IRC: samu@pirc.pl)
#
# ----------------------------------------------------------
#
# Seend is a seen script that will tell you how long ago the bot
# last seen the specified nick, what channel they were on, and what their
# last message was to that channel. It also allows you to do partial
# nick searches using * and even lets you .seen yourself!
#
# Seend uses an automatic system for backing up and restoring seen
# data. Which also includes the .seend partyline command for manually
# backing up and restoring seen data.
#
# In the config section owners can enable/disable: User name prefixing,
# displaying last channel, and displaying last message. Also can set
# up Not seen responses, bot search for self response, backup file
# location/name, automatic backup interval time, toggle seen requests,
# interval backup logging, show time as duration, and public & dcc command triggers.
#
# Initial channel setup:
# (starts logging and enables .seen command)
# .chanset #channel +seend
#
# Public command syntax:
# .seen ?nick|help|*?
#
# DCC (partyline) command syntax:
# .seend ?backup|restore?
#
# Example Usage:
# (public)
# <lee8oi> .seen help
# <dukelovett> ~Seend 1.8~ Usage: .seen ?nick|help|*?
# <lee8oi> .seen
# <dukelovett> lee8oi: I last saw you 1 hour 3 minutes 39 seconds ago on
# #dukelovett. Last message: Sseen script was awsome. My version improves on it.
# <lee8oi> .seen dukelovett
# <dukelovett> lee8oi: I last saw myself just now. Right here.
# <lee8oi> .seen lee*
# <dukelovett> lee8oi: The pattern 'lee*' matches: lee8oi
#
# (console)
# <lee8oi> .seend
# <dukelovett> ~Seend 1.8~ Usage: Seend ?backup|restore?
# <lee8oi> .seend backup
# <dukelovett> Seend data backup performed.
# <lee8oi> .seend restore
# <dukelovett> Seend data restore performed.
#
# Note:
# Automatic backup system saves seen data on .die & .restart and
# restores data on load. Interval backups are every 15 mins by default.
#
# Thanks:
# Thanks to thommey, nml375, and jack3 for their great code suggestions
# and all the helpful answers that made this script possible.
#
# Updates:
# v1.8
# 1. Added configuration for enabling/disabling interval backup logging.
# 2. Added configuration to enable/disable showing last seen time as duration.
# 3. Created get_info procedure to grab seen info and format the output
# message according to configuration.
#
# v1.8 new fixes:
# 1. Fixed bug in seend data saving. Script now correctly ignores lines that
# start with the currently set public seen command trigger. Which can 
# now also be set in configuration along with the dcc trigger.
# 2. Fixed bug that prevented names with caps from being retrieved correctly
# 3. Fixed another bug with caps issues.
#
# ----------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------
#
# Public command trigger 
variable pubCmd !seen
#
# DCC command trigger
variable dccCmd seend
#
# Not Seen Responses
#
# note: Escape special characters with '\' example: '\{'
# in the message.
#
## 1.When users supply their own nick or no nick, and bot has NOT seen them:
set isUsersOwn "I haven't seen you yet. Say something."
#
## 2.When users supply an other nick and bot has NOT seen it yet:
set isOtherUser "I haven't seen that nick so far. They might not have spoken yet."
#
## 3.When users supply the bots own name:
set isBotsName "I last saw myself just now! Right here."
#
# ----------------------------------------------------------
# Seen Results
# (0=disable,1=enable)
#
## 1.Prefix results with users name.
variable usename 1
#
## 3.Show last channel in results.
variable showchannel 1
#
## 2.Show last message in results.
variable showmessage 1
#
## 3.Show last seen time as duration. (1=enable,0=disable)
# (off shows date and time instead)
variable showduration 1
#
#
# ----------------------------------------------------------
# Backup file
#
## Set relative path to backup file.
variable backupfile "scripts/SeendData.tcl"
#
## set backup interval time in minutes.
variable interval 15
#
## log interval backups. Uses 'putlog'. (1=enable,0=disable)
variable logintervals 0
#
## log .seen requests. Uses 'putlog'. (1=enable,0=disable)
variable logseens 0
#

# ----------------------------------------------------------
# END CONFIGURATION
#
# NOTE: Only edit below if you know what you are doing. Any
# Incorrectly editing code can cause undesirable results.
#
####################################################################
variable isUsersOwn [split $isUsersOwn]
variable isOtherUser [split $isOtherUser]
variable isBotsName [split $isBotsName]
variable lastseen
variable lastchan
variable lastmsg
variable ver "1.8.3"
}
bind pubm - * ::seend::pub_msg_save
bind sign - * ::seend::pub_msg_save
bind pub - [set ::seend::pubCmd] ::seend::pub_show_seen
bind evnt - prerestart ::seend::prerestart
bind evnt - loaded ::seend::loaded
bind dcc n [set ::seend::dccCmd] ::seend::dcc
setudef flag seend
if {![info exists ::seend_dietrace]} {
   # .die trigger. do backup
   trace add execution *dcc:die enter ::seend::backup
   trace add execution *msg:die enter ::seend::backup
}
if {![info exists timer_running]} {
   # no existing timer. start new one.
   timer [set seend::interval] ::seend::timer_proc
   set timer_running 1
}
namespace eval seend {
   proc restore {args} {
      # restore from file
      source [set seend::backupfile]
   }
   proc prerestart {type} {
      # prerestart trigger. do backup.
      ::seend::backup
      putlog "Seend data saved."
   }
   proc loaded {type} {
      # bot loaded trigger do restore.
      ::seend::restore
      putlog "Seend data restored."
   }
   
   proc timer_proc {args} {
      # call self at timed intervals. do backup
      ::seend::backup
      timer [set seend::interval] ::seend::timer_proc
      if {[set seend::logintervals]} {
         # logging is enabled.
         putlog "Interval Seend backup performed."
      }
      return 1
   }
   proc backup {args} {
      # backup to file: Write lines to file so it can
      # be sourced as a script during restore.
      variable ::seend::lastseen
      variable ::seend::lastchan
      variable ::seend::lastmsg
      set fs [open [set seend::backupfile] w+]
      # write variable lines for loading namespace vars.
      puts $fs "variable ::seend::lastseen"
      puts $fs "variable ::seend::lastchan"
      puts $fs "variable ::seend::lastmsg"
      # create 'array set' lines using array data.
      foreach arr {lastseen lastchan lastmsg} {
         puts $fs "array set $arr [list [array get $arr]]"
      }
      close $fs;
   }
   proc dcc {handle idx text} {
      # dcc/partyline .seend command
      set text [string tolower [lindex [split $text] 0]]
      if {$text == "" || $text == "help"} {
         # show help.
         variable ::seend::ver
         putdcc $idx "~Seend $ver~ Usage: .[set ::seend::dccCmd] ?backup|restore?"
      } elseif {$text == "backup"} {
         # run backup procedure.
         ::seend::backup
         putdcc $idx "Seend data saved."
      } elseif {$text == "restore"} {
         # run restore procedure.
         ::seend::restore
         putdcc $idx "Seend data restored."
      }
   }
   proc pub_msg_save {nick userhost handle channel text} {
      # grab seen data from channel message.
      set first [lindex [split $text] 0]
      if {[channel get $channel seend]} {
         # channel has seend flag
         if {$first != [set ::seend::pubCmd]} {
            # not a .seen request. Ok to save.
            set seend::lastseen($nick) [clock seconds]
            set seend::lastchan($nick) $channel
            set seend::lastmsg($nick) $text
         } else {
            variable ::seend::logseens
            if {$logseens} {
               putlog "New .seen request from $nick: $text"
            }
         }
      }
   }
   proc get_info {nick who} {
      variable ::seend::lastseen
      variable ::seend::lastchan
      variable ::seend::lastmsg
      set chanmsg ""
      set storedmsg ""
      set time $lastseen($who)
      if {[set ::seend::showduration] == 1} {
         set last "[duration [expr {[clock seconds] - $time}]] ago"
      } else {
         set last [string map {"\n" ""} [clock format $time -format {%Y/%m/%d %H:%M:%S}]]
      }
      if {[set seend::showchannel]} {
         # showchannel is enabled. Add last channel.
         set chanmsg " on $lastchan($who)"
      }
      if {[set seend::showmessage]} {
         # show message is enabled. Add last message.
         set storedmsg " Last message: $lastmsg($who)"
      }
      if {[string tolower $nick] == [string tolower $who]} {
         set result "I last saw you $last${chanmsg}.${storedmsg}"
      } else {
         set result "I last saw $who $last${chanmsg}.${storedmsg}"
      }
      return $result
   }
   proc pub_show_seen {nick userhost handle channel text} {
      # Retrive and display seen info or help.
      if {[channel get $channel seend]} {
         variable ::seend::lastseen
         variable ::seend::lastchan
         variable ::seend::lastmsg
         set name ""
         set chanmsg ""
         set storedmsg ""
         # channel has sseen flag set
         set otext [lindex [split $text] 0] 
         set ctext [string tolower $otext]
         set lnick [string tolower $nick]
         if {[set seend::usename]} {
            # usename is enabled. Add nick.
            set name "${nick}: "
         }
         if {$ctext == "help"} {
            # No args supplied. Show help:
            variable ::seend::ver
            putserv "PRIVMSG $channel :~Seend $ver~ Usage: [set ::seend::pubCmd] ?nick|help|\*?"
         } elseif {[isbotnick $otext]} {
            # User supplied bots name as arg
            variable ::seend::isBotsName
            putserv "PRIVMSG $channel :${name}[join [lrange $isBotsName 0 end]]"
         } elseif {[regexp {\*} $otext]} {
            # text includes a * so it must be a pattern search.
            set namelist [array names lastseen $otext]
            if { $namelist != "" } {
               # names matching pattern exist.
               putserv "PRIVMSG $channel :${name}The pattern '${otext}' matches: ${namelist}"
            } else {
               # no names match pattern.
               putserv "PRIVMSG $channel :${name}No match found for '${otext}'."
            }
         } elseif {$ctext == $lnick || $ctext == ""} {
            # User supplied their own name or no name.
            if {[info exists lastseen($nick)]} {
               # seen data available
               set output [::seend::get_info $nick $nick]
               putserv "PRIVMSG $channel :${name}$output"
            } else {
               # seen data not available.
               variable ::seend::isUsersOwn
               putserv "PRIVMSG $channel :${name}${isUsersOwn}"
            }
         } else {
            # User supplied other user name
            if {[info exists lastseen($otext)]} {
               # seen data available
               set output [::seend::get_info $nick $otext]
               putserv "PRIVMSG $channel :${name}$output"
            } else {
               # seen data not available.
               variable ::seend::isOtherUser
               putserv "PRIVMSG $channel :${name}${isOtherUser}"
            }
         }
      }
   }
   namespace export backup restore prerestart loaded dcc pub_msg_save pub_show_seen
}
putlog "Seend [set ::seend::ver] loaded!"
