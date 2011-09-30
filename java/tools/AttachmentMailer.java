package tools;

import java.io.*;
import java.util.*; 
import javax.mail.*; 
import javax.mail.internet.*; 
import javax.activation.*;
import java.util.LinkedList;

/**
 * Class to send email with attachments
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class AttachmentMailer
{
  private LinkedList<String> attachmentFiles = null; // List of files to attach
  private LinkedList<String> destAddresses   = null; // List of email destinations
  private String senderEmail                 = null; // Who is sending email
  private String emailSubject                = null; // Email subject
  private String emailBody                   = null; // Text of email
  private String emailHost                   = null;
  
  /**
   * class constructor - reads emailhost name from config file EmailHost.config
   * packaged with the Jar file.
   * @param attachFiles
   * @param dest
   * @param sender
   * @param subject
   * @param body
   * @throws IOException 
   */
  public AttachmentMailer(LinkedList<String> attachFiles, LinkedList<String> dest,
                     String sender, String subject, String body) throws Exception
  {
    this.attachmentFiles = attachFiles;
    this.destAddresses   = dest;
    this.senderEmail     = sender;
    this.emailSubject    = subject;
    this.emailBody       = body;
//    this.emailHost       = "smtp.bcm.tmc.edu";
    
    InputStream is = getClass().getResourceAsStream("EmailHost.config");
    BufferedReader reader = new BufferedReader(new InputStreamReader(is));
    String line = reader.readLine();
    
    if(line != null)
      emailHost = getValue(line);
    if(emailHost == null || emailHost.isEmpty())
    {
      throw new Exception("Did not find value of email host in the config file EmailHost.config");
    }
    
    if(reader != null)
      reader.close();
    if(is != null)
     is.close();
  }
  
  /**
   * Method to send the email
   * @throws Exception
   */
  public void sendMail() throws Exception
  {
    Properties props = System.getProperties();
    props.put("mail.smtp.host", emailHost);
	   
    Session session = Session.getInstance(props, null);
			   
    Message message = new MimeMessage(session);
    message.setFrom(new InternetAddress(senderEmail));

    InternetAddress[] toAddress = new InternetAddress[destAddresses.size()];

    for (int i = 0; i < destAddresses.size(); i++)
    {
      toAddress[i] = new InternetAddress(destAddresses.get(i));
    }
    
    message.setRecipients(Message.RecipientType.TO, toAddress);    
    message.setSubject(emailSubject.toString());
    BodyPart messageBodyPart = new MimeBodyPart();

    if(emailBody.equals(""))
    {
      messageBodyPart.setText("Please see the attached file(s)");
    }
    else
    {
      messageBodyPart.setText(emailBody);
    }
    
    Multipart multipart = new MimeMultipart();
    multipart.addBodyPart(messageBodyPart);
    
    for(int i = 0; i < attachmentFiles.size(); i++)
    {
      messageBodyPart = new MimeBodyPart();
      DataSource source = new FileDataSource(attachmentFiles.get(i));
      messageBodyPart.setDataHandler(new DataHandler(source));
      messageBodyPart.setFileName(attachmentFiles.get(i));
      multipart.addBodyPart(messageBodyPart);
    }
    
    message.setContent(multipart);
    try
    {
      Transport.send(message);
    }
    catch(Exception e)
    {
      System.err.println(e.toString());
    }
  }
  
  public static void main(String[] args)
  {
    parseParams(args);
  }
  
  private static void printUsage()
  {
    System.err.println("Program to send email with attachments. Multiple attachments are supported");
    System.err.println("Sender=value    Sender email address");
    System.err.println("Sub=value       Email subject");
    System.err.println("Body=value      Email body");
    System.err.println("Dest=value      Email destination. Multiple values supported");
    System.err.println("Attach=value    Attachment files. Multiples values supported");
  }
  
  /**
   * Parse the parameters, validate them and send email
   * @param args
   */
  private static void parseParams(String[] args)
  {
    boolean foundSender           = false;
    boolean foundDest             = false;
    boolean foundAttachment       = false;
    String sender                 = null;
    String subject                = null;
    String body                   = null;
    LinkedList<String>dest        = new LinkedList<String>();
    LinkedList<String>attachments = new LinkedList<String>();
    String temp                   = null;
    
    for(int i = 0; i < args.length; i++)
    {
      if(args[i].toLowerCase().startsWith("sender="))
      {
        sender = getValue(args[i]);
        
        if(sender != null && !sender.isEmpty())
          foundSender = true;
      }
      else
      if(args[i].toLowerCase().startsWith("sub"))
      {
        subject = getValue(args[i]);
      }
      else
      if(args[i].toLowerCase().startsWith("body"))
      {
        body = getValue(args[i]);
      }
      else
      if(args[i].toLowerCase().startsWith("dest"))
      {
        temp = getValue(args[i]);
        if(temp != null || !temp.isEmpty())
        {
          foundDest = true;
          dest.add(temp);
        }
      }
      else
      if(args[i].toLowerCase().startsWith("attach"))
      {
        temp = getValue(args[i]);
        if(temp != null || !temp.isEmpty())
        {
          File f = new File(temp);
          if(!f.exists())
          {
            System.err.println("Specified file " + temp + " does not exist");
            System.exit(-2);
          }
          foundAttachment = true;
          attachments.add(temp);
        }
      }
    }
    if(!foundSender || !foundDest || !foundAttachment)
    {
      System.err.println("Found sender = " + foundSender);
      System.err.println("Found dest   = " + foundDest);
      System.err.println("Found attach = " + foundAttachment);
      printUsage();
      System.exit(-1);
    }
    else
    {
      if(subject == null || subject.isEmpty())
      {
        subject = "Email with attachments";
      }
      if(body == null || body.isEmpty())
      {
        body = "See the attachments";
      }
      try
      {
        AttachmentMailer emailSender = 
         new AttachmentMailer(attachments, dest, sender, subject, body);
        emailSender.sendMail();
      }
      catch(Exception e)
      {
        System.err.println(e.getMessage());
        e.printStackTrace();
        System.exit(-1);
      }
    }
  }

  /**
   * Parse the parameter=value string and return the value
   * @param nameValuePair
   * @return
   */
  private static String getValue(String nameValuePair)
  {
    int idx = nameValuePair.indexOf("=");
    
    if(idx < 0)
      return null;
    else
      return nameValuePair.substring(idx + 1);
  }
}
