#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

class FindFCForCleaning
  def initialize(baseDir)
    initializeMembers()

    buildInstrumentList(baseDir)

    @instrList.each do |instrName|
      puts "Checking for new flowcells for sequencer : " + instrName.to_s
      @instrDir = baseDir + "/" + instrName.to_s

#      puts "Directory : " + @instrDir.to_s
      findNewFlowcells()
    end
  end

private
  def initializeMembers()
    @instrDir  = ""                   # Directory of instrument
    @instrList = ""                   # List of instruments
    @fcList    = nil                  # Flowcell list
    @newFC     = Array.new            # Flowcell to analyze

    @fcList = Array.new
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


  # Find flowcells for which analysis is not yet started. Read the directory
  # listing under the instrument directory, compare directories against the list
  # of completed flowcells and find the directories (flowcells) that are new.
  def findNewFlowcells()
    @newFC = Array.new

    dirList = Dir.entries(@instrDir)

    dirList.each do |dirEntry|
      if !dirEntry.eql?(".") && !dirEntry.eql?("..") &&
         File::directory?(@instrDir + "/" + dirEntry) &&
         isAvailableForCleaning(@instrDir + "/" + dirEntry)
         @newFC << dirEntry

         puts dirEntry.slice(/[0-9A-Za-z]+$/).gsub(/^[AB]/, "") + " " + @instrDir + "/" + dirEntry
      end
    end      
  end

  # Method to determine if a flowcell can be cleaned or not. For a flowcell to
  # be cleaned, all of the following conditions must be true :
  # 1) Marker file ".rsync_finished" must be present
  # 2) It must have been modified 20 days ago (i.e. 1728000 seconds earlier)
  # 3) The flowcell must not have been cleaned earlier (i.e., it must have L001
  #    through L008 directories in its Data/Intensities directory
  def isAvailableForCleaning(fcName)
     markerName = fcName + "/.rsync_finished"  

    if File::exist?(markerName)
      modTime  = File::mtime(markerName)

      timeDiff = (Time.now- modTime)
      intensityLaneDir = fcName + "/Data/Intensities/L00*"
   
      intensityLaneDir = Dir[fcName + "/Data/Intensities/L00*"]
      
      # If intensitiy directory has directories L001 through L008 and
      # modification time of .rsync_finished is 20 days (i.e. 1728000 seconds)
      # that flowcell is available for cleaning.
      # Please note: To change the interval of when a flowcell becomes a
      # candidate flowcell for cleaning, please change the number below.
      if intensityLaneDir != nil && intensityLaneDir.length > 0 && (timeDiff > 1728000)
         return true
       end
    end

    return false
  end
end

obj = FindFCForCleaning.new("/stornext/snfs0/next-gen/Illumina/Instruments")
