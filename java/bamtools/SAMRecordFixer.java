package bamtools;

import net.sf.samtools.SAMRecord;

/**
 * Class to fix SAMRecord. Currently, the only available action is to fix
 * CIGAR for unmapped reads.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class SAMRecordFixer
{
  /**
   * For SAM records written by BWA, some unmapped reads contain non-empty
   * CIGAR and mapping quality > 0, which causes Picard's SamFileValidator
   * to complain. This function fixes those reads. If the read is unmapped,
   * it's CIGAR is reset and mapping quality set to zero.
   * @param rec
   * @return
   */
  public static SAMRecord fixCIGARForUnmappedReads(SAMRecord rec)
  {
    if(rec.getReadUnmappedFlag())
    {
      if(rec.getCigarLength() > 0)
        rec.setCigarString("*");
      if(rec.getMappingQuality() > 0)
        rec.setMappingQuality(0);
    }
    return rec;
  }
}
