#!/usr/bin/ruby

# Class to obtain the execution environment information for the current process
# Author Nirav Shah niravs@bcm.edu

class EnvironmentInfo

  # Method to return the hostname 
  def self.getHostName()
    hostName = `hostname`
    return hostName.to_s
  end

  # Return the PBS job ID
  def self.getSchedulerJobID()
    jobID = `echo $PBS_JOBID`

    if jobID == nil || jobID.empty?()
      return "none"
    else
     return jobID
    end
  end

  # Return the free disk space on the temp drive on the execution host
  def self.getTmpDriveCharacteristics()
    cmd = "df -h /space1/tmp"
    output = `#{cmd}`
    return output.to_s
  end

  # Show all the environment information on specified destination. This method 
  # accepts a boolean parameter to decide whether to display characteristics 
  # of the tmp drive. This is because under error conditions, this drive can 
  # fail. As a result, the command to obtain free disk space on tmp drive may 
  # never return. Thus, let the caller choose whether to show this information
  #  or not.
  def self.displayEnvironmentInformation(dest, showTmpDriveInfo)
    dest.puts "Working directory : " + Dir.pwd.to_s
    dest.puts "Hostname          : " + getHostName().to_s
    dest.puts "PBS Job ID        : " + getSchedulerJobID()

    if showTmpDriveInfo == true
       dest.puts "Characteristics of /space1/tmp : "
       dest.puts getTmpDriveCharacteristics().to_s
    end
  end
end
