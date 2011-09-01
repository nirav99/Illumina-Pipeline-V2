package analyzer.SequenceAnalyzer;

import java.io.*;
import java.util.*;

/**
 * Helper class for UniquenesCalculator. It reads the file and calculates
 * the number of total and unique reads from it.
 * @author Nirav Shah niravs@bcm.edu
 *
 * It uses disk based sorting with priority queues to sort the lines of the 
 * file. This approach should allow this class to be used when sequences from
 * many sequencing events are to be examined for uniqueness.
 */
class UniquenessHelper
{
  private int totalReads         = 0;        // Total reads in given file
  private int uniqueReads        = 0;        // Num. unique reads in given file
  private File tempDir           = null;     // where to write temp files
  private String memoryBuffer[]  = null;     // to hold records in memory
  private int MAX_READS_IN_RAM   = 10000000; // Max records to store in memory
  private int index              = 0;
  private ArrayList<File> tempFileList;      // List of temporary files
  
  /**
   * Class constructor.
   * @param inputFile
   * @param tempDir
   * @throws Exception
   */
  UniquenessHelper(BufferedReader inputFile, File tempDir) throws Exception
  {
    memoryBuffer = new String[MAX_READS_IN_RAM];
    this.tempDir = tempDir;
    tempFileList = new ArrayList<File>();
    readInputFile(inputFile, tempDir);    
  }
  
  int getTotalReads()
  {
    return totalReads;
  }
  
  int getUniqueReads()
  {
    return uniqueReads;
  }
  
  /**
   * Read the input file. Sort reads in memory or spill them to temp file.
   * @param reader
   * @param tempDir
   * @throws Exception
   */
  private void readInputFile(BufferedReader reader, File tempDir) throws Exception
  {
    String line;
	    
     while((line = reader.readLine()) != null)
     {
       if(index >= MAX_READS_IN_RAM)
       {
         spillToTempFile(memoryBuffer.length);
         index = 0;
       }
       memoryBuffer[index++] = line;
     }
      
     /*
      * The total number of records in file was less than the the maximum
      * in-memory limit. Hence, perform in-memory uniqueness computation. 
      */
     if(tempFileList.isEmpty())
     {
       countUnique(index);
     }
     else
     {
       spillToTempFile(index);
       // Now read temp files and find unique values.
       MergeAndComputeResults merge = new MergeAndComputeResults(tempFileList);
       totalReads  += merge.totalReads;
       uniqueReads += merge.uniqueReads;
     }
  }
  
  /**
   * Helper method to sort the records in memory and write them to a temporary
   * file on disk.
   * @param size - Number of records to sort
   * @throws Exception
   */
  private void spillToTempFile(int size) throws Exception
  {
    File tempFile = File.createTempFile("uniqsegment", ".tmp", tempDir);
    tempFile.deleteOnExit();
    
    BufferedWriter writer = new BufferedWriter(new FileWriter(tempFile));
    tempFileList.add(tempFile);
    
    Arrays.sort(memoryBuffer, 0, size);
    
    for(int i = 0; i < size; i++)
    {
      writer.write(memoryBuffer[i]);
      writer.newLine();
    }
    writer.close();
  }
  
  /**
   * Sort all reads from in-memory buffer and update the values of
   * total reads and unique reads.
   * @param size
   */
  private void countUnique(int size)
  {
    String lastRecord = "";
    String nextRecord = "";
    
    totalReads += size;
    
    Arrays.sort(memoryBuffer, 0, size);
    
    for(int i = 0; i < size; i++)
    {
      nextRecord = memoryBuffer[i];
      
      if(!nextRecord.equalsIgnoreCase(lastRecord))
      {
        uniqueReads++;
      }
      lastRecord = nextRecord;
    }
  }
}

/**
 * Class to read the temp files generated from a single file bucket and obtain
 * number of unique reads.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
class MergeAndComputeResults
{
  private PriorityQueue<String> pQueue; // To get least string
  private String setOfLines[];          // Next set of lines, one line per file
  private BufferedReader readerList[];  // List of file readers
  int totalReads  = 0;
  int uniqueReads = 0;
  
  /**
   * Class Constructor
   * @param tempFileList
   * @throws Exception
   */
  MergeAndComputeResults(ArrayList<File> tempFileList) throws Exception
  {
    setOfLines = new String[tempFileList.size()];
    readerList = new BufferedReader[tempFileList.size()];
    pQueue = new PriorityQueue<String>();
    
   // Create instances of readers to read temp files
    for(int i = 0; i < tempFileList.size(); i++)
    {
      readerList[i] = new BufferedReader(new FileReader(tempFileList.get(i)));
    }
    mergeResults();
    
    for(int i = 0; i < tempFileList.size(); i++)
      readerList[i].close();
  }

  /**
   * Read all temp files, add lines to priority queue and calculate the
   * number of unique reads. 
   * @throws Exception
   */
  void mergeResults() throws Exception
  {
    String last = "";
    String next = "";
    
    readNextSetOfLines();
    
    while(true)
    {
      // Break out if no more data to read
      if(noMoreDataToRead())
        break;
      
      // Get the next line
      next = pQueue.poll();
      totalReads++;
      
      // If lines are different, update unique reads
      if(!next.equalsIgnoreCase(last))
        uniqueReads++;

      last = next;
      
      for(int i = 0; i < setOfLines.length; i++)
      {
        if(next.equalsIgnoreCase(setOfLines[i]))
        {
          addLineToPQ(i);
        }
      }
    }
    
    // Read out the remaining lines from priority queue
    while(!pQueue.isEmpty())
    {
      next = pQueue.poll();
      totalReads++;
      if(!next.equalsIgnoreCase(last))
        uniqueReads++;
      last = next;
    }
  }
  
  /**
   * Read next line from each open file
   * @throws Exception
   */
  private void readNextSetOfLines() throws Exception
  {
    for(int i = 0; i < readerList.length; i++)
    {
      addLineToPQ(i);
    }
  }
  
  /**
   * Adds the specified line to priority queue.
   * @param i
   * @throws Exception
   */
  private void addLineToPQ(int i) throws Exception
  {
    setOfLines[i] = readerList[i].readLine();
    if(setOfLines[i] != null)
    {
      pQueue.offer(setOfLines[i]);
    }
  }
  
  /**
   * Method to test if all lines from all temp files have been read.
   * @return - true - if all data has been read, false otherwise.
   */
  private boolean noMoreDataToRead()
  {
    for(int i = 0; i < setOfLines.length; i++)
      if(setOfLines[i] != null)
        return false;
    return true;
  }
}
