package limsClient;

import org.w3c.dom.*;

/**
 * Class to encapsulate information necessary to analyze a given lane
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class LaneInfo
{
  String fcType         = null; // Flowcell type
  String refPath        = null; // Reference path
  String library        = null; // Library
  String sample         = null; // Sample
  String chipDesign     = null; // Capture chip design
  String numCyclesRead1 = null; // Number of cycles for read1
  String numCyclesRead2 = null; // Number of cycles for read2
  String laneBarcode    = null; // Lane barcode
  
  /**
   * Class constructor - build the object from LIMS response string
   * @param laneBarcode
   * @param inputString
   */
  public LaneInfo(String laneBarcode, String inputString)
  {
    String delimiter = ";";
    this.laneBarcode = extractLaneBarcode(laneBarcode);
    
    String tokens[] = inputString.trim().split(delimiter);
  
    for(int i = 0; i < tokens.length; i++)
    {
      if(tokens[i].startsWith("FLOWCELL_TYPE="))
      {
    	if(tokens[i].equals("FLOWCELL_TYPE=p"))
          fcType = "paired";
    	else
          fcType = "fragment";
      }
      else
      if(tokens[i].startsWith("BUILD_PATH="))
      {
        refPath = getValue(tokens[i]);
      }
      else
      if(tokens[i].startsWith("Library="))
      {
        library = getValue(tokens[i]);
      }
      else
      if(tokens[i].startsWith("Sample="))
      {
        sample = getValue(tokens[i]);
      }
      else
      if(tokens[i].startsWith("ChipDesign"))
      {
        chipDesign = getValue(tokens[i]);
      }
      else
      if(tokens[i].startsWith("NUMBER_OF_CYCLES_READ1="))
      {
        numCyclesRead1 = getValue(tokens[i]);
      }
      else
      if(tokens[i].startsWith("NUMBER_OF_CYCLES_READ2="))
      {
        numCyclesRead2 = getValue(tokens[i]);
      }
    }
  }
  
  /**
   * Split one token and return the value portion of the token
   * @param keyValString
   * @return
   */
  private String getValue(String keyValString)
  {
    String values[] = keyValString.split("=");
    
    if(values == null || values[1] == null || values[1].isEmpty())
      return null;
    else
      return values[1];
  }
  
  /**
   * Accept fcBarcode of the form FC-Lane-Barcode and return Lane-Barcode.
   * @param fcBarcode
   * @return
   */
  private String extractLaneBarcode(String fcBarcode)
  {
    return fcBarcode.substring(fcBarcode.indexOf("-") + 1);
  }
  
  /**
   * Return an XML corresponding to the state of this object
   * @param doc
   * @return
   */
  public Element toXML(Document doc)
  {
    Element element = doc.createElement("LaneBarcode");
    element.setAttribute("ID", laneBarcode.toString());
    
    if(refPath != null && !refPath.isEmpty())
      element.setAttribute("ReferencePath", refPath);
    else
      element.setAttribute("ReferencePath", "sequence");
    
    if(library != null && !library.isEmpty())
      element.setAttribute("Library", library.toString());
    
    if(sample != null && !sample.isEmpty())
      element.setAttribute("Sample", sample.toString());
    
    if(chipDesign != null && !chipDesign.isEmpty())
      element.setAttribute("ChipDesign", chipDesign.toString());
    return element;
  }
}
