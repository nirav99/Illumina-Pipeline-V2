#!/usr/bin/ruby

$:.unshift File.join(File.dirname(__FILE__), ".", "..", "lib")

require 'PipelineHelper'
require 'BWAParams'
require 'EmailHelper'

# Class to email analysis results
# Author: Nirav Shah niravs@bcm.edu

class ResultMailer

  # Class constructor
  def initialize()
    @bamFile        = ""
    @emailText      = ""
    @emailSubject   = ""
    @attachments    = nil
    buildEmailSubject()
    buildEmailText()
    findAttachmentFiles()
  end

  # Send email
  def emailResults()
    from = "sol-pipe@bcm.edu"

    obj = EmailHelper.new()

    # Find the list of people to send the email to
    # In the file ../config/email_recepients.txt, use the list corresponding to
    # the label EMAIL_RESULTS
    to = obj.getResultRecepientEmailList()

    if @attachments != nil && @attachments.length > 0
      obj.sendEmailWithAttachment(from, to, @emailSubject, @emailText.join(""), @attachments)
    else
      obj.sendEmail(from, to, @emailSubject, @emailText.join(""))
    end
  end

  private

  # Method to build the subject of the email
  def buildEmailSubject()
    begin
      configParams = BWAParams.new()
      configParams.loadFromFile()
      library      = configParams.getLibraryName()
      fcBarcode    = configParams.getFCBarcode()
    rescue
      if fcBarcode == nil || fcBarcode.empty?()
        fcBarcode = "unknown"
      end
    end

     # Fill in the fields for sending the email
    @emailSubject = "Illumina Alignment Results : Flowcell " + fcBarcode.to_s

    if library != nil && !library.empty?
       @emailSubject = @emailSubject + " Library : " + library.to_s
    end
  end

  # Method to build the body of the email
  def buildEmailText()
    uniqText = ""
    mappingText = nil

    uniquenessResult = Dir["*_uniqueness.txt"]

    if uniquenessResult != nil && uniquenessResult.length > 0
      uniqText = IO.readlines(uniquenessResult[0])
    end

    if File::exist?("BWA_Map_Stats.txt")
      mappingText = IO.readlines("BWA_Map_Stats.txt")
      @emailText = mappingText
      @emailText <<  "\r\n\r\n"
    end

    @emailText << "Sequence Quality Analysis"
    @emailText << "\r\n\r\n"
    @emailText << uniqText
    @emailText << "\r\n\r\n"
    @emailText << "File System Path : " + Dir.pwd.to_s
  end

  # Find all png files in the directory and attach them in email.
  def findAttachmentFiles()
    @attachments = Array.new
    pngFiles     = Dir["*.png"]

    pngFiles.each do |file|
        @attachments << file
    end
  end
end

obj = ResultMailer.new()
obj.emailResults()
