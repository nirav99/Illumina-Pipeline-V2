package analyzer.SequenceAnalyzer;

import java.util.Arrays;
import analyzer.Common.*;
import net.sf.picard.fastq.FastqRecord;

/**
 * Class to calculate the number adaptor reads in the sequences.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class AdaptorCalculator extends MetricsCalculator
{
  private int totalReadsRead1    = 0;    // Number of "READ1" reads
  private int totalReadsRead2    = 0;    // Number of "READ2" reads
  private int numAdaptorRead1    = 0;    // Number of adaptor reads in "READ1"
  private int numAdaptorRead2    = 0;    // Number of adaptor reads in "READ2"
  private String adaptorSeq      = null; // Adaptor sequence
  
  /**
   * Class constructor
   */
  public AdaptorCalculator()
  {
    super();
    adaptorSeq = "GATCGGAA";
  }
 
  /**
   * Process the next read
   */
  @Override
  void processRead(FastqRecord read1, FastqRecord read2) throws Exception
  {
    if(read1 == null)
    {
      throw new Exception("Encountered null/empty record for read 1");
    }
    String sequenceRead1 = read1.getReadString();
    String sequenceRead2 = null;
    
    if(read2 != null)
    {
      sequenceRead2 = read2.getReadString();
    }
		    
    if(sequenceRead1.length() > maxLen)
      maxLen = sequenceRead1.length();
    if(sequenceRead2 != null && sequenceRead2.length() > maxLen)
      maxLen = sequenceRead2.length();
    
    if(maxLen > distRead1.length)
    {
      distRead1 = Arrays.copyOf(distRead1, maxLen);
    }
    if(sequenceRead2 != null && maxLen > distRead2.length)
    {
      distRead2 = Arrays.copyOf(distRead2, maxLen);
    }
    totalReadsRead1++;
    findMatchWithAdaptor(sequenceRead1, ReadType.READ1);
    
    if(sequenceRead2 != null && !sequenceRead2.isEmpty())
    {
      totalReadsRead2++;
      findMatchWithAdaptor(sequenceRead2, ReadType.READ2);
    }
    sequenceRead1 = null;
    sequenceRead2 = null;
  }

  /**
   * Calculate the final result and plot the graph
   */
  @Override
  void calculateResult()
  {
    for(int i = 0; i < distRead1.length && totalReadsRead1 > 0; i++)
    {
      distRead1[i] = distRead1[i] / totalReadsRead1 * 100.0; 
    }
    for(int i = 0; i < distRead2.length && totalReadsRead2 > 0; i++)
    {
      distRead2[i] = distRead2[i] / totalReadsRead2 * 100.0;
    }
    plotDistribution();
  }
	
  /**
   * Build the result object.
   */
  @Override
  void buildResultMetrics()
  {
    System.err.println("Total reads read1 : " + totalReadsRead1 + " num adaptors = " + numAdaptorRead1);
    System.err.println("Total reads read2 : " + totalReadsRead2 + " num adaptors = " + numAdaptorRead1);
    if(totalReadsRead1 <= 0)
      return;
    resultMetric = new ResultMetric();
    resultMetric.setMetricName("AdaptorReadCount");
    double percentAdaptor = numAdaptorRead1 * 1.0 / totalReadsRead1 * 100.0;
    resultMetric.addKeyValue("PercentAdaptorRead1", 
    		                     getFormattedNumber(percentAdaptor));
    
    if(totalReadsRead2 > 0)
    {
      percentAdaptor = numAdaptorRead2 * 1.0 / totalReadsRead2 * 100.0;
      resultMetric.addKeyValue("PercentAdaptorRead2", 
	                             getFormattedNumber(percentAdaptor));
    }
  }
	
  /**
   * Method to perform adaptor screening
   * @param sequence
   * @param readType
   */
  private void findMatchWithAdaptor(String sequence, ReadType readType)
  {
    int startPoint = -1;
    
    startPoint = sequence.indexOf(adaptorSeq);
    
    // Found the adaptor sequence, update the corresponding counter
    if(startPoint >= 0 && startPoint < sequence.length())
    {
      if(readType == ReadType.READ1)
      {
        distRead1[startPoint]++;
        numAdaptorRead1++;
      }
      else
      {
        distRead2[startPoint]++;
        numAdaptorRead2++;
      }
    }
  }

  /**
   * Helper method to plot the distribution of Percentage of N vs Base position.
   */
  private void plotDistribution()
  {
    int xAxisLength = distRead1.length;

    if(totalReadsRead2 > 0 && distRead2.length > distRead1.length)
    {
      xAxisLength = distRead2.length;
    }
    double xAxis[] = new double[xAxisLength];
    
    for(int i = 0; i < xAxis.length; i++)
      xAxis[i] = (i + 1);

    try
    {
      if(totalReadsRead1 > 0 && distRead1.length > 0)
      {
        if(totalReadsRead2 > 0 && distRead2.length > 0)
        {
          p = new Plot("AdaptorReadDistribution.png", 
        		       "Distribution of adaptor reads per base position",
        		       "Base Position", "Number of reads having adaptor", "Read 1", "Read 2",
        		       xAxis, distRead1, distRead2);
        }
        else
        {
          p = new Plot("AdaptorReadDistribution.png", 
        		       "Distribution of adaptor reads per base position",
        		       "Base Position", "Number of reads having adaptor", "Read 1",
                       xAxis, distRead1);
        }
        p.setYScale(0, 100);
        p.setXScale(0, maxLen);
        p.plotGraph();
      }
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
