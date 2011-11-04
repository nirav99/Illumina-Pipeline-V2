#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

# This script searches for all new flowcells that have finished copying and
# analysis has not been started for them. On finding a "new" flowcell, it starts
# the analysis. It also adds this flowcell's name to done_list.txt (in instrument
# directory). This prevents the same flowcell from being analyzed multiple
# times.
# Author: Nirav Shah niravs@bcm.edu
 
require 'asshaul.rb'
require 'fileutils'
require 'PipelineHelper.rb'
require 'PathInfo'

# Class to automatically start the flowcells. It runs as part of a crontab job.
# On detecting that a flowcell has copied, it starts the analysis automatically.
# It searches for each child directory (corresponding to an instrument
# directory) in the base directory passed to this class. To change the search
# volume, change the parameter passed to this class's constructor.
#
# Author: Nirav Shah niravs@bcm.edu

class AnalysisStarter
  def initialize()
    initializeMembers()

    baseDir = PipelineHelper.getInstrumentRootDir()
    puts "Root directory to look for new flowcells : " + baseDir

    # Attempt to obtain the lock, if another instance of this program is
    # running, this operation will fail. Print a suitable message and exit.
    if !@lock.try_to_lock
      puts "Another instance of this program is running. Exiting..."
      exit 0
    end
    buildInstrumentList(baseDir)

    @instrList.each do |instrName|
      puts "Checking for new flowcells for sequencer : " + instrName.to_s
      @instrDir = baseDir + "/" + instrName.to_s

      puts "Directory : " + @instrDir.to_s
      buildAnalyzedFCList()
      findNewFlowcells()

      @newFC.each do |fcName|
        if fcReady?(fcName) == true
          updateDoneList(fcName)
          processFlowcell(fcName)
        end
      end

    # Release the lock to allow another instance of this program to run.
    @lock.unlock
    end
  end

private
  def initializeMembers()
    @instrDir  = ""                   # Directory of instrument
    @instrList = ""                   # List of instruments
    @fcList    = nil                  # Flowcell list
    @completedFCLog = "done_list.txt" # List of flowcells analyzed
    @newFC     = Array.new            # Flowcell to analyze

    # Create a new lock - this acts like a Singleton pattern for this program.
    # The lock is a file "lock_$filename" in the directory where this code
    # lives.  It is used to prevent multiple instance of this program from
    # running at the same time.
    @lock      = Locker.new(File.dirname(__FILE__) + "/lock_startAnalysis.lock")
  end

  # Method to build a list of instruments
  def buildInstrumentList(baseDir)
    entries = Dir[baseDir + "/*"] 

    @instrList = Array.new

    entries.each do |entry|
      if !entry.eql?(".") && !entry.eql?("..") &&
         File::directory?(entry)

         @instrList << entry.slice(/[a-zA-Z0-9]+$/).to_s
      end
    end
  end

  # Build a hashtable of flowcells for which analysis was already started
  def buildAnalyzedFCList()
    logFile = @instrDir + "/" + @completedFCLog
    puts logFile
    @fcList = nil
    @fcList = Hash.new()
 
    if File::exist?(logFile)
      lines = IO.readlines(logFile)

      if lines != nil && lines.length > 0
        lines.each do |line|
          @fcList[line.strip] = "1"
        end 
      end
    else
       # If this directory is newly created and it does not have the log of
       # completed flowcells, create this file.
       cmd = "touch " + logFile
       `#{cmd}`
    end
  end

  # Find flowcells for which analysis is not yet started. Read the directory
  # listing under the instrument directory, compare directories against the list
  # of completed flowcells and find the directories (flowcells) that are new.
  def findNewFlowcells()
    @newFC = Array.new

    dirList = Dir.entries(@instrDir)

    dirList.each do |dirEntry|
      if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
         File::directory?(@instrDir + "/" + dirEntry) &&
         !@fcList.key?(dirEntry.strip)
         @newFC << dirEntry
      end
    end      
  end

  # Accurate as of 26th Sept 2011:
  # Every HiSeq flowcell running RTA version 1.12 that is copied directly to the
  # cluster will have a marker file RTAComplete.txt written at the end of copy
  # operation. On finding this file, we add another marker file .rsync_finished.
  # In this case, this flowcell will be picked up for analysis in the next
  # iteration of cron job.

  # For GAIIx flowcells running RTA version 1.9, RTAComplete.txt is not written.
  # However, we can assume that all GAIIx flowcells are paired-end, and look for
  # the following files 
  # Basecalling_Netcopy_complete.txt,
  # Basecalling_Netcopy_complete_READ1.txt
  # Basecalling_Netcopy_complete_READ2.txt
  # If these files are copied more than an hour ago, add .rsync_finished, which
  # will allow this flowcell to be picked up in the next iteration of cron job
  def fcReady?(fcName)
    fcDir = @instrDir + "/" + fcName
    puts "FCDir : " + fcDir.to_s
    if File::exist?(fcDir + "/.rsync_finished")
      return true
    end
   
    if fcName.match(/SN601/) 
       puts "Flowcell " + fcName + " is not configured for automatic analysis"
       return false
    end

    # If the marker file RTAComplete.txt was written more than 1 hour ago, then
    # add the new marked file and return.
    if File::exist?(fcDir + "/RTAComplete.txt")
      cmd = "touch " + @instrDir + "/" + fcName + "/.rsync_finished"
      `#{cmd}`
    else
       rtaVersion = PipelineHelper.findRTAVersion(fcName) 

       if rtaVersion != nil && rtaVersion.match(/1\.9/)
         puts "Flowcell with RTA version 1.9 found : " + fcName

         if File::exist?(fcDir + "/Basecalling_Netcopy_complete.txt") &&
            File::exist?(fcDir + "/Basecalling_Netcopy_complete_READ1.txt") &&
            File::exist?(fcDir + "/Basecalling_Netcopy_complete_READ2.txt") 
 
            modificationTime = Time.now - File::mtime(fcDir + "/Basecalling_Netcopy_complete.txt")
            puts "Mod time : " + modificationTime.to_s
            if modificationTime >= 3600
              return true
            else
              return false
            end
         else
           return false
         end
       end
    end
    return false
  end

  # Add the entry of the flowcell to "done" list so that it won't be processed
  # more than once.
  def updateDoneList(fcName)
    logFileName = @instrDir + "/" + @completedFCLog
    logFile = File.new(logFileName, "a")
    puts "Adding to log : " + logFileName + " FC : " + fcName.to_s
    logFile.puts fcName
    logFile.close 
  end

  # Start the analysis for the flowcell. 
  def processFlowcell(fcName)
    puts "Starting analysis for flowcell : " + fcName.to_s
    currDir = Dir.pwd
    Dir::chdir(PathInfo::BIN_DIR)
    cmd = "ruby PreProcessor.rb  fcname=" + fcName.to_s + " action=all"
    puts "Running command : " + cmd.to_s
=begin
    output = `#{cmd}`
    puts output
=end
    Dir::chdir(currDir)
  end
end

obj = AnalysisStarter.new()
