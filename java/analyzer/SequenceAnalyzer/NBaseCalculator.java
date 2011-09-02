package analyzer.SequenceAnalyzer;

import java.util.Arrays;
import analyzer.Common.*;
import net.sf.picard.fastq.FastqRecord;

/**
 * Class to calculate the number of "N" bases, i.e. undetermined bases
 * in the sequences.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class NBaseCalculator extends MetricsCalculator
{
  private int totalReadsRead1 = 0;  // Total number of READ1 reads
  private int totalReadsRead2 = 0;  // Total number of READ2 reads
  private int badReadsRead1   = 0;  // Reads having > threshold% of N in read 1
  private int badReadsRead2   = 0;  // Reads having > threshold% of N in read 2
  
  // When number of Ns in a read exceeds this threshold, mark it bad
  private double threshold    = 0.15;
  
  /**
   * Inner class to represent spike of N bases in the sequences
   *
   */
  class spike
  {
    int startPoint;  // Starting base position of the spike
    int width;       // Width of the spike
    
    boolean greaterThan(spike s2)
    {
      if(this.width > s2.width)
        return true;
      else
        return false;
    }
  }
  
  /**
   * Class constructor
   */
  public NBaseCalculator()
  {
    super();
  }

  /* 
   * Process the next read
   */
  @Override
  void processRead(FastqRecord read1, FastqRecord read2) throws Exception
  {
    if(read1 == null)
    {
      throw new Exception("Encountered null/empty fastq record for read 1");
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
    calculateNs(sequenceRead1, ReadType.READ1);
    
    if(sequenceRead2 != null && !sequenceRead2.isEmpty())
    {
      totalReadsRead2++;
      calculateNs(sequenceRead2, ReadType.READ2);
    }
    sequenceRead1 = null;
    sequenceRead2 = null;
  }

  /* 
   * Build the result object
   */
  @Override
  void buildResultMetrics()
  {
    if(totalReadsRead1 <= 0)
    {
      resultMetric = null;
      return;
    }
    resultMetric = new ResultMetric();
    resultMetric.setMetricName("DistributionOfN");
    resultMetric.addKeyValue("Bad_Reads_Read1",
                             Integer.toString(badReadsRead1));
    spike s = spikeDetector(ReadType.READ1);
    
    if(s.width > 0)
    {
      ResultMetric m = new ResultMetric();
      m.setMetricName("NBasesExceedingThresholdRead1");
      m.addKeyValue("StartPosition", Integer.toString(s.startPoint));
      m.addKeyValue("Width", Integer.toString(s.width));
      resultMetric.addResultMetric(m);
    }
    if(totalReadsRead2 > 0)
    {
      resultMetric.addKeyValue("Bad_Reads_Read2",
                               Integer.toString(badReadsRead2));
      
      s = spikeDetector(ReadType.READ2);
      if(s.width > 0)
      {
        ResultMetric m = new ResultMetric();
        m.setMetricName("NBasesExceedingThresholdRead2");
        m.addKeyValue("StartPosition", Integer.toString(s.startPoint));
        m.addKeyValue("Width", Integer.toString(s.width));
        resultMetric.addResultMetric(m);
      }
    }
  }

  /* 
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
   * Helper method to calculate Ns for a given read
   * @param sequence
   * @param readType
   */
  private void calculateNs(String sequence, ReadType readType)
  {
    int numN = 0;
    
    for(int i = 0; i < sequence.length(); i++)
    {
      if(sequence.charAt(i) == 'N' || sequence.charAt(i) == 'n')
      {
        numN++;
        if(readType == ReadType.READ1)
        {
          distRead1[i]++;
        }
        else
        {
          distRead2[i]++;
        }
      }
    }
    
    if(numN >= threshold * sequence.length())
    {
      if(readType == ReadType.READ1)
        badReadsRead1++;
      else
        badReadsRead2++;
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
          p = new Plot("DistributionOfN.png", "Distribution of N per base position",
                       "Base Position", "Percentage of N", "Read 1", "Read 2",
                       xAxis, distRead1, distRead2);
        }
        else
        {
          p = new Plot("DistributionOfN.png", "Distribution of N per base position",
                       "Base Position", "Percentage of N", "Read 1",
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
  
  /**
   * Helper method to detect the spike - significant increase in N bases
   * in the distribution arrays
   * @param trendArray
   */
  private spike spikeDetector(ReadType readType)
  {
    int heightThreshold       = 25;
    int widthThreshold        = 3;
    int spikeStart            = -1;
    int width                 = 0;
    double trendArray[]       = null;

    spike largestSpike = new spike();
    
    if(readType == ReadType.READ1)
    {
      trendArray = distRead1;
    }
    else
    {
      trendArray = distRead2;
    }

    for(int i = 0; i < trendArray.length; i++)
    {
      width = 0;
      
      while(i < trendArray.length && trendArray[i] >= heightThreshold)
      {
        width++;
        i++;
      }
      if(width >= widthThreshold)
      {
        spikeStart = i - 1 - width;
        spike s    = new spike();
        s.startPoint = spikeStart;
        s.width      = width;
 
        if(s.greaterThan(largestSpike))
          largestSpike = s;
        System.err.println("Found a spike of N starting at position : " + spikeStart + " of width : " + width);
        s = null;
      }
    }
    return largestSpike;
  }
}
