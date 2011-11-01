#!/usr/bin/ruby

$:.unshift File.dirname(__FILE__)
require 'EmailHelper'

# Class to provide abstract error handling behavior. Current behavior is to
# email the error message and exit.
# To be extended to write errors to a common log.
# Author: Nirav Shah niravs@bcm.edu

class ErrorHandler
  # Method to handle error. Current behavior, print the error stage and abort.
  def self.handleError(msg)

    obj          = EmailHelper.new()
    emailFrom    = "sol-pipe@bcm.edu"
    emailTo      = obj.getErrorRecepientEmailList()

    if msg.msgDetail != nil
      emailBody = msg.msgDetail
    else
      emailBody = "No detailed error message specified"
    end

    if msg.msgBrief != nil && !msg.msgBrief.eql?("")
      emailSubject = msg.msgBrief.to_s
    else
      emailSubject = "Illumina pipeline error"
    end

    if msg.workingDir != nil && !msg.workingDir.eql?("")
      emailBody = emailBody + "\r\nWorking Directory : " + msg.workingDir.to_s
    end
    if msg.hostName != nil && !msg.hostName.eql?("")
      emailBody = emailBody + "\r\nHostname : " + msg.hostName.to_s
    end
    if msg.jobID != nil && !msg.jobID.eql?("")
      emailBody = emailBody + "\r\nJob ID : " + msg.jobID.to_s
    end
    if msg.fcBarcode != nil && !msg.fcBarcode.eql?("")
      emailBody = emailBody + "\r\nFlowcell Barcode : " + msg.fcBarcode.to_s
    end

    obj.sendEmail(emailFrom, emailTo, msg.msgBrief, emailBody)
    exit -1
  end
end

# Class to encapsulate an error message
class ErrorMessage
  attr_accessor :fcBarcode, :workingDir, :hostName, :jobID, :msgBrief, :msgDetail
end
