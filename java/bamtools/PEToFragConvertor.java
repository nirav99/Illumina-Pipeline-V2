package bamtools;

import net.sf.picard.cmdline.CommandLineProgram;
import net.sf.picard.cmdline.Option;
import net.sf.picard.cmdline.StandardOptionDefinitions;
import net.sf.picard.cmdline.Usage;
import net.sf.picard.io.IoUtil;
import net.sf.samtools.*;

import java.io.File;
import java.io.IOException;

/**
 * Class to convert a paired-end BAM to a fragment BAM. It eliminates read2
 * from the BAM and erases all duplicate flags.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class PEToFragConvertor extends CommandLineProgram
{
  @Usage
  public String USAGE = getStandardUsagePreamble() + " Read SAM/BAM file " +
  " and remove read 2. It also resets duplicate flags from read 1.";
	   
  @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, 
		  doc = "Input SAM/BAM to be converted to a fragment.")
  public File INPUT;
	
  @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME,
          doc = "Where to write new SAM/BAM.")
  public File OUTPUT;
  
  public static void main(String[] args)
  {
    new PEToFragConvertor().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    try
    {
	  IoUtil.assertFileIsReadable(INPUT);
	  IoUtil.assertFileIsWritable(OUTPUT);
	
	  int numReadsProcessed = 0;
	  int numReadsWritten   = 0;
	
	  SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);
      SAMFileReader reader = new SAMFileReader(INPUT);
      SAMFileWriter writer = new
      SAMFileWriterFactory().makeSAMOrBAMWriter(reader.getFileHeader(), true, OUTPUT);
      SAMRecord rec    = null;
      SAMRecord newRec = null;
    
      SAMRecordIterator it = reader.iterator();
    
      while(it.hasNext())
      {
        numReadsProcessed++;
        if(numReadsProcessed % 10000000 == 0)
        {
          System.err.print("Processed : " + numReadsProcessed + " reads\r");
        }
        rec = it.next();
      
        newRec = processRead(rec);
      
        if(newRec != null)
        {
          writer.addAlignment(newRec);
          numReadsWritten++;
        }
      }
    
      System.out.println("Number of reads read    : " + numReadsProcessed);
      System.out.println("Number of reads written : " + numReadsWritten);
    
      writer.close();
      reader.close();
      it.close();
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
   * On processing fragment or first pair reads, erase pair flag and dup flag.
   * On encountering second read, return null.
   * @param rec
   * @return
   */
  protected SAMRecord processRead(SAMRecord rec)
  {
    SAMRecord newRecord = null;

    if(!rec.getReadPairedFlag() || (rec.getReadPairedFlag() && rec.getFirstOfPairFlag()))
    {
      newRecord = rec;
      newRecord.setReadPairedFlag(false);
      newRecord.setFirstOfPairFlag(false);
      newRecord.setProperPairFlag(false);
      newRecord.setDuplicateReadFlag(false);
      newRecord.setMateNegativeStrandFlag(false);
      newRecord.setMateUnmappedFlag(false);
      
      newRecord.setInferredInsertSize(0);
      newRecord.setMateAlignmentStart(0);
      newRecord.setMateReferenceIndex(0);
      newRecord.setMateReferenceName("");
      
      if(newRecord.getReadUnmappedFlag())
      {
        String cigarString = newRecord.getCigarString();
        
        if(cigarString != null && !cigarString.equals("*"))
          newRecord.setCigarString(null);
        if(newRecord.getMappingQuality() > 0)
          newRecord.setMappingQuality(0);
      }
    }
    return newRecord;
  }
}
