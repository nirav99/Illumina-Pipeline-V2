package barcodes;

import java.util.*;
import java.io.*;

/**
 * Class to calculate frequency of occurrences of various barcodes in a given
 * Illumina lane. This tool reads in a text file containing the list of barcodes
 * found in the qseq files of the given lane.
 * Author: Nirav Shah niravs@bcm.edu
 */
public class BarcodeFrequencyCounter
{
  private Hashtable<String, Integer>freq = null;
  private String barcodeList[] = null;
  private int barcodeCount[] = null;
  
  /**
   * Class constructor. The input file is a text file containing the list of
   * barcode sequences to analyze, one entry per line.
   */
  public BarcodeFrequencyCounter(String fileName) throws Exception
  {
    String line;
    Integer val;
    
    BufferedReader reader = new BufferedReader(new FileReader(new
                                File(fileName)));
    freq = new Hashtable<String, Integer>();
    
    while((line = reader.readLine()) != null)
    {
      if(!freq.containsKey(line))
        freq.put(line, new Integer(1));
      else
      {
        val = freq.get(line);
        val = val + 1;
        freq.remove(line);
        freq.put(line, val);
      }
      val  = null;
      line = null;
    }
    
    reader.close();
  }
  
  /**
   * Method to show the list and frequency of topmost K barcodes.
   * It allocates an array of K elements. Whenever, it finds a barcode that
   * whose frequency is more than the least frequent sequence in the array, it
   * replaces the least sequence and its frequency with the new value.
   * Finally, it reports the topmost K sequences and their frequencies.
   */
  public void showMax(int maxFreq)
  {
    barcodeList  = new String[maxFreq];
    barcodeCount = new int[maxFreq];
    int minIdx, val;
    
    Enumeration keys = freq.keys();
        
    for(int i = 0; i < maxFreq && keys.hasMoreElements(); i++)
    {
      String key = (String) keys.nextElement();
      val    = freq.get(key);
      barcodeList[i]  = key;
      barcodeCount[i] = val;
    }
   
    while(keys.hasMoreElements())
    {
      String key = (String) keys.nextElement();
      val = freq.get(key);
      minIdx = findLeastIndex();
      
      if(val > barcodeCount[minIdx])
      {
        barcodeList[minIdx] = key;
        barcodeCount[minIdx] = val;
      }
    }
    
    for(int i = 0; i < barcodeList.length; i++)
    {
      System.out.println("Barcode Sequence : " + barcodeList[i] + " Frequency : " + barcodeCount[i]);
    }
  }
  
  /**
   * Method to obtain the index of the sequence that is least frequency in the
   * list of sequences currently in "top K" list.
   */
  private int findLeastIndex()
  {
    int minIdx = 0;
    for(int i = 1; i < barcodeCount.length; i++)
    {
      if(barcodeCount[i] < barcodeCount[minIdx])
        minIdx = i;
    }
    return minIdx;
  }
  
  private int findLeast()
  {
    return barcodeCount[findLeastIndex()];
  }
  
  public static void main(String args[])
  {
    int topKBarcodes;

    if(args.length != 2)
    {
      printUsage();
      System.exit(-1);
    }
    try
    {
        
      BarcodeFrequencyCounter counter = new BarcodeFrequencyCounter(args[0]);
      topKBarcodes = Integer.parseInt(args[1]);
      counter.showMax(topKBarcodes);
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }

  /**
   * Show usage information.
   */
  public static void printUsage()
  {
    System.err.println("Tool to show the distribution of most frequent K barcodes");
    System.err.println();
    System.err.println("Usage:");
    System.err.println("Input parameters : InputFile TopKBarcodes");
    System.err.println("  InputFile    - File containing barcode sequences");
    System.err.println("  TopKBarcodes - Number of most frequent barcodes to show");
    System.err.println("  e.g Value 1 shows only most frequent barcode sequence");
    System.err.println("  e.g Value 5 shows top 5 most frequent barcode sequences");
  }
}
