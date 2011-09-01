package analyzer.SequenceAnalyzer;

import net.sf.picard.cmdline.*;
import net.sf.picard.io.IoUtil;
import java.io.File;
import java.util.*;

import net.sf.picard.fastq.FastqReader;
import net.sf.picard.fastq.FastqRecord;

import analyzer.Common.*;

/**
 * Driver class to analyzer sequence files and calculate percentage of unique
 * reads, distribution of adaptor reads, and distribution of "N" bases.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class SequenceAnalyzer extends CommandLineProgram
{
  @Usage
  public String USAGE = getStandardUsagePreamble() +
  "Read Fastq sequence files and number of unique reads and other metrics.\r\n";
	  
  @Option(shortName = "R1", doc = "Sequence file for read 1")
  public File Read1;
  
  @Option(shortName = "R2", doc = "Sequence file for read 2", optional=true)
  public File Read2;

  @Option(doc = "Stop after debugging N reads. Mainly for debugging. Default value: 0, which means process the whole file")
  public int STOP_AFTER = 0;
  
  @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME, doc = "Output file to write results in txt format", optional=true)
  public File OUTPUT;

  @Option(shortName = "X", doc = "File with results in XML format", optional=true)
  public File XMLOUTPUT;
  
  public static void main(String[] args)
  {
    new SequenceAnalyzer().instanceMainWithExit(args);
  }
  
  /**
   * Method to do the actual work
   */
  @Override
  protected int doWork()
  {
    FastqReader reader1  = null;  // To read sequence file for read1
    FastqReader reader2  = null;  // To read sequence file for read2
    FastqRecord record1  = null;  // Fastq record for read1
    FastqRecord record2  = null;  // Fastq record for read2
    String sequenceRead1 = null;  // Read sequence from fastq record of read1
    String sequenceRead2 = null;  // Read sequence from fastq record of read2
    
    long totalReads       = 0;
    
    boolean isFragment = (Read2 == null) ? true : false;
    
    IoUtil.assertFileIsReadable(Read1);
    reader1 = new FastqReader(Read1);
    
    if(!isFragment)
    {
      IoUtil.assertFileIsReadable(Read2);
      reader2 = new FastqReader(Read2);
    }
    ArrayList<MetricsCalculator> metrics = new ArrayList<MetricsCalculator>();
    metrics.add(new NBaseCalculator());
    metrics.add(new AdaptorCalculator());
    metrics.add(new UniquenessCalculator(TMP_DIR));
    
    try
    {
      while(true)
      {
        if(reader1.hasNext())
          record1 = reader1.next();
        else
          record1 = null;
      
        if(isFragment == false && reader2.hasNext())
          record2 = reader2.next();
        else
          record2 = null;
      
        if(record1 == null && record2 == null)
          break;

        totalReads++;

        if(totalReads > 0 && totalReads % 10000000 == 0)
          System.err.println("\r" + totalReads);

        for(int i = 0; i < metrics.size(); i++)
          metrics.get(i).processRead(record1, record2);
        
        if(STOP_AFTER > 0 && totalReads >= STOP_AFTER)
          break;
      }
      
      reader1.close();
      if(!isFragment)
        reader2.close();
      
     ArrayList<ResultMetric> resultMetrics = new ArrayList<ResultMetric>();
      
     for(int i = 0; i < metrics.size(); i++)
     {
       metrics.get(i).calculateResult();
       metrics.get(i).buildResultMetrics();
       if(metrics.get(i).getResultMetrics() != null)
         resultMetrics.add(metrics.get(i).getResultMetrics());
     }
     logResults(resultMetrics);
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      return -1;
    }
    return 0;
  }
  
  /**
   * Helper method to log the results in various formats.
   * @param resultMetrics
   * @throws Exception
   */
  private void logResults(ArrayList<ResultMetric>resultMetrics) throws Exception
  {
    ArrayList<Logger> loggers = new ArrayList<Logger>();
    
    if(OUTPUT != null)
      loggers.add(new TextLogger(OUTPUT));
    if(XMLOUTPUT != null)
      loggers.add(new XmlLogger(XMLOUTPUT));
      
    for(int i = 0; i < resultMetrics.size(); i++)
    {
      for(int j = 0; j < loggers.size(); j++)
        loggers.get(j).logResult(resultMetrics.get(i));
    }
 
    for(int i = 0; i < loggers.size(); i++)
      loggers.get(i).closeFile();
  }
}
