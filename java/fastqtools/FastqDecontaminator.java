package fastqtools;

import net.sf.picard.cmdline.*;
import net.sf.picard.fastq.FastqReader;
import net.sf.picard.fastq.FastqRecord;
import net.sf.picard.fastq.FastqWriter;
import net.sf.picard.io.IoUtil;
import java.io.*;
import java.util.*;

/**
 * Class to split Illumina fastq files based on their index tags
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class FastqDecontaminator extends CommandLineProgram
{
  @Usage
   public String USAGE = getStandardUsagePreamble() +
   "Read Illumina Fastq sequence files. Filter the reads based on\r\n" +
   "the purity of the index tags. Reads with tag that completely match\r\n" +
   "the specified tag, or differ in at most 1 base position are written\r\n" +
   "to the output fastq files. Other reads are not written to output files\r\n";

  @Option(shortName = "R1", doc = "Read 1 fastq file")
  public File READ1;
  
  @Option(shortName = "R2",optional=true, doc = "Read 2 fastq file")
  public File READ2;
  
  @Option(shortName = "T", doc = "Index tag")
  public String TAG;
  
  private int numReads        = 0;      // Number of reads in original files
  private int numReadsWritten = 0;      // Number of reads written (pure reads)
  private boolean isFragment  = false;  // If true, READ2 does not exist, it is
                                        // fragment
  
  public static void main(String[] args)
  {
    new FastqDecontaminator().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    String key = null;
    FastqWriter writer1  = null;
    FastqWriter writer2  = null;
    FastqReader reader1  = null;  // To read sequence file for read1
    FastqReader reader2  = null;  // To read sequence file for read2
    FastqRecord record1  = null;  // Fastq record for read1
    FastqRecord record2  = null;  // Fastq record for read2


    if(READ2 == null)
      isFragment = true;

    IoUtil.assertFileIsReadable(READ1);
    reader1 = new FastqReader(READ1);
    writer1 = new FastqWriter(new File(getOutputFileName(READ1)));
   
    if(!isFragment)
    {
      IoUtil.assertFileIsReadable(READ2);
      reader2 = new FastqReader(READ2);
      writer2 = new FastqWriter(new File(getOutputFileName(READ2)));
    }
    
    try
    {
      while(true)
      {
        record1 = (reader1.hasNext()) ? reader1.next() : null;
 
        if(!isFragment)
          record2 = (reader2.hasNext()) ? reader2.next() : null;
			
        if(record1 == null || (!isFragment && record2 == null))
          break;
			
        numReads++;
        
        if((isFragment == false && indexTagsEqual(record1.getReadHeader(), record2.getReadHeader()) ||
            isFragment == true))
        {
          key = getIndexTag(record1.getReadHeader());

          if(keepRead(key))
          {
            writer1.write(record1);
            if(!isFragment)
              writer2.write(record2);
            numReadsWritten++;
          }
        }
      }
      reader1.close();
      writer1.close();
      
      if(!isFragment)
      {
        reader2.close();
        writer2.close();
      }
     
      System.out.println("Total Pairs of Reads : " + numReads);
      System.out.println("Total Pairs written  : " + numReadsWritten);
      System.out.println("Total Pairs thrown   : " + (numReads - numReadsWritten));
      System.out.println("Percentage Written   : " + 1.0 * (numReadsWritten) / numReads * 100.0);
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      System.exit(-1);
    }
    return 0;
  }
  
  /**
   * Extract the index tag from the read.
   */
  private String getIndexTag(String readName)
  {
    int startIndex = readName.indexOf("#") + 1;
    int endIndex   = readName.indexOf("/");
    return readName.substring(startIndex, endIndex);
  }
  
  /**
   * Method to check if index tags of two reads are equal.
   */
  private boolean indexTagsEqual(String readName1, String readName2)
  {
    return getIndexTag(readName1).equals(getIndexTag(readName2));
  }
  
  /**
   * Method to get the output file name
   * @param file
   * @return
   */
  private String getOutputFileName(File file)
  {
    String inputName = file.getName();
    
    return inputName + ".filtered_sequence";
  }
  
  /**
   * Method to check if the read is contaminated. If the index tag in the read
     equals the tag provided by user, or they differ in exactly one position,
     then return true - meaning no contamination, else return false, to prevent
     this read from being written to output.
  */
  private boolean keepRead(String indexTagToCheck)
  {
    if(TAG.equals(indexTagToCheck))
      return true;
    else
    if(distKApart(TAG, indexTagToCheck, 1))
      return true;
    else
      return false;
  }
  
  /**
   * Method to check if given reads are editDist (K) apart from each other.
   */
  private boolean distKApart(String s1, String s2, int editDist)
  {
    int diffLen = s1.length() - s2.length();
      
    if(diffLen < 0)
      diffLen *= -1;
    
    if(diffLen == editDist)
      return true;
    
    int diffCount = diffLen;
    
    for(int i = 0; i < Math.min(s1.length(), s2.length()); i++)
    {
      if(s1.charAt(i) != s2.charAt(i))
      {
        diffCount++;
      }
    }
    if(diffCount == editDist)
      return true;
    else
      return false;
  }
}
