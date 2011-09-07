package bamtools;

import java.io.File;

import net.sf.picard.cmdline.CommandLineProgram;
import net.sf.picard.cmdline.Option;
import net.sf.picard.cmdline.StandardOptionDefinitions;
import net.sf.picard.cmdline.Usage;
import net.sf.picard.io.IoUtil;
import net.sf.picard.sam.SamPairUtil;
import net.sf.picard.util.PeekableIterator;
import net.sf.samtools.*;
import net.sf.samtools.SAMFileHeader.SortOrder;

/**
 * Custom implementation of the class to fix mate information that works with
 * unsorted SAM files produced by BWA and generates a coordinate sorted output
 * SAM or BAM file with mate information fixed and unmapped reads fixed. It 
 * eliminates sorting the input file based on query name. Use only on SAM files
 * produced by BWA. For more general applications, use Picard's
 * FixMateInformation.jar.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class MateInfoFixer extends CommandLineProgram
{
  @Usage
  public String USAGE = getStandardUsagePreamble() +
  "Read SAM/BAM and fix mate information in it. The resulting file \r\n" +
  "is written in coordinate sorted order.";

  @Option(shortName = StandardOptionDefinitions.INPUT_SHORT_NAME, doc = "Input SAM/BAM to be fixed.")
  public File INPUT;

  @Option(shortName = StandardOptionDefinitions.OUTPUT_SHORT_NAME,
          doc = "Where to write fixed SAM/BAM.")
  public File OUTPUT;

  @Option(shortName = "FUR", doc = "Fix CIGAR and mapping quality for unmapped reads ", 
          optional=true)
  public boolean FIXUNMAPPEDREADS = true;
  
  protected SAMFileWriter writer;

  public static void main(String[] args)
  {
    new MateInfoFixer().instanceMainWithExit(args);
  }
  
  @Override
  protected int doWork()
  {
    IoUtil.assertFileIsReadable(INPUT);
    int numReadsProcessed = 0;
	      
    OUTPUT = OUTPUT.getAbsoluteFile();
    IoUtil.assertFileIsWritable(OUTPUT);
    
    SAMFileHeader header;
    SAMFileReader.setDefaultValidationStringency(SAMFileReader.ValidationStringency.SILENT);
    final SAMFileReader reader = new SAMFileReader(INPUT);
    header = reader.getFileHeader();
    header.setSortOrder(SortOrder.coordinate);
    createSamFileWriter(header);
    
    final PeekableIterator<SAMRecord> iterator = new PeekableIterator<SAMRecord>(reader.iterator());
    SAMRecord rec1;
    SAMRecord rec2;
    
    while(iterator.hasNext())
    {
      rec1 = iterator.next();
      rec2 = iterator.hasNext() ? iterator.peek() : null;
      
      if(rec2 != null && rec1.getReadName().equals(rec2.getReadName()))
      {
        iterator.next();
        SamPairUtil.setMateInfo(rec1, rec2, header);
        writeAlignment(rec1);
        writeAlignment(rec2);
        numReadsProcessed += 2;
      }
      else
      {
        writer.addAlignment(rec1);
        numReadsProcessed++;
      }
      
      if(numReadsProcessed % 10000000 == 0)
        System.err.println("Processed " + numReadsProcessed + " reads\r");
    }
    iterator.close();
    writer.close();
    return 0;
  }
  
  /**
   * Helper method to create a new SAM/BAM file for writing.
   * @param header
   */
  protected void createSamFileWriter(final SAMFileHeader header)
  {
    header.setSortOrder(SortOrder.coordinate);
    writer = new SAMFileWriterFactory().makeSAMOrBAMWriter(header, false, OUTPUT);
  }
  
  /**
   * Write the SAM records to the new file while fixing CIGAR if required.
   * @param rec
   */
  protected void writeAlignment(SAMRecord rec)
  {
    if(FIXUNMAPPEDREADS)
    {
      SAMRecord r2 = SAMRecordFixer.fixCIGARForUnmappedReads(rec);
      writer.addAlignment(r2);
      r2 = null;
    }
    else
      writer.addAlignment(rec);
  }
}
