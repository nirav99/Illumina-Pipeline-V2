package analyzer.SequenceAnalyzer;

import java.text.DecimalFormat;
import java.text.NumberFormat;
import analyzer.Common.*;
import net.sf.picard.fastq.FastqRecord;

/**
 * Generic class representing the interface to be followed by concrete classes
 * that calculate various metrics.
 * @author Nirav Shah niravs@bcm.edu
 */
public abstract class MetricsCalculator
{
  protected ResultMetric resultMetric;     // Result metric
  protected Plot p;                        // To generate plots
  private NumberFormat formatter;          // To format numbers
  
  protected double distRead1[]     = null; // Distribution of metric in read 1
  protected double distRead2[]     = null; // Distribution of metric in read 2
  protected int maxLen             = 0;    // Max. read length seen so far
  
  /**
   * Class constructor
   */
  public MetricsCalculator()
  { 
    resultMetric = new ResultMetric();
    p = null;
    formatter = new DecimalFormat("#0.00");
    distRead1 = new double[maxLen];
    distRead2 = new double[maxLen];
  }
  
  abstract void processRead(FastqRecord record1, FastqRecord record2) throws Exception;
  abstract void calculateResult();
  abstract void buildResultMetrics();
  
  public ResultMetric getResultMetrics()
  {
    return resultMetric;
  }
  
  /**
   * Helper method to truncate doubles to 2 decimal places and return a string
   * @param d
   * @return
   */
  protected String getFormattedNumber(double d)
  {
    return formatter.format(d);
  }
}

/**
 * Enum representing two read types, read one or read 2
  *
 */
enum ReadType
{
  READ1,
  READ2
}
