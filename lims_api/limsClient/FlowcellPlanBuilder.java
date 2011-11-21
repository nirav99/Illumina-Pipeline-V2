package limsClient;

import java.io.*;
import org.w3c.dom.*;
import javax.xml.parsers.*;
import javax.xml.transform.*;
import javax.xml.transform.dom.*;
import javax.xml.transform.stream.*;

/**
 * Class to build the flowcell plan definition by interacting with LIMS
 * @author Nirav Shah niravs@bcm.edu
 */
public class FlowcellPlanBuilder extends LIMSClient
{
  // LIMS URL to obtain flowcell barcode info
  private String flowcellInfoPage = "getFlowCellInfo.jsp"; 
  
  // LIMS URL to obtain information for specified lane barcode
  private String laneInfoPage     = "getAnalysisPreData.jsp"; 
                            
  private String fcName     = null; // Name of the flowcell to query LIMS for
  private String fcPlanFile = null; // Name of the output File
  
  private String fcBarcodes[]    = null;  // Array of flowcell barcodes
  private LaneInfo barcodeInfo[] = null;  // Array of analysis information for
                                          // each barcode
  private BufferedWriter writer  = null;  // The output XML file
  
  /**
   * Class constructor - needs to know which LIMS database to connect to
   * @param databaseName
   * @throws IOException
   * @throws Exception
   */
  public FlowcellPlanBuilder(String databaseName, String fcName, String outFile) 
         throws IOException,Exception
  {
     super(databaseName);
     this.fcName     = fcName;
     this.fcPlanFile = outFile;
     
     writer = new BufferedWriter(new FileWriter(new File(fcPlanFile)));
  }
  
  /**
   * Overridden method to perform the action
   */
  @Override
  public void process()
  {
    try
    {
      getFlowcellBarcodeInfo();
      getBarcodeInfo();
      writeXML();
    }
    catch(Exception e)
    {
      printError("Exception occurred while obtaining flowcell plan : " + e.getMessage());
      e.printStackTrace();
      
      try
      {
        if(writer != null) writer.close();
      }catch(Exception e2) { }
      System.exit(-1);
    }
  }
  
  /**
   * Helper method to get list of barcodes for a given flowcell
   * @throws Exception
   */
  private void getFlowcellBarcodeInfo() throws Exception
  {
    String completeURL = limsBaseURL + "/" + flowcellInfoPage + "?flowcell_barcode=" +
                         fcName;
    printInfo("Sending HTTP request " + completeURL);
    boolean error = sendGETRequest(completeURL);
    
    if(error)
    {
      printError("Error in receiving information about lane barcodes");
      System.exit(-1);
    }
    else
    {
      fcBarcodes = responseContent.toString().split("\n");
    }
  }
  
  /**
   * Given a lane barcode, retrive all the information necessary to analyze that barcode.
   * @param laneBarcode
   * @throws Exception
   */
  private void getBarcodeInfo() throws Exception
  {
	barcodeInfo = new LaneInfo[fcBarcodes.length];
    String baseURL = limsBaseURL + "/" + laneInfoPage + "?lane_barcode=";
    boolean error;
    
    for(int i = 0; i < fcBarcodes.length; i++)
    {                     
      String completeURL = baseURL + fcBarcodes[i];
      printInfo("Sending HTTP request " + completeURL);
      error = sendGETRequest(completeURL);
      
      if(error)
      {
        printError("Error occurred in receiving barcode list");
        System.exit(-1);
      }
      else
      {
        LaneInfo info = new LaneInfo(fcBarcodes[i], responseContent.toString());
        barcodeInfo[i] = info;
      }
    }
  }
  
  /**
   * Write the output from LIMS in an XML file.
   * @throws Exception
   */
  private void writeXML() throws Exception
  {
    DocumentBuilderFactory dbfac = DocumentBuilderFactory.newInstance();
    DocumentBuilder docBuilder = dbfac.newDocumentBuilder();
    Document doc = docBuilder.newDocument();
    Element root = doc.createElement("FCInfo");
    Element LaneBarcodeList = doc.createElement("LaneBarcodeList");
    Element LaneBarcodeInfo = doc.createElement("LaneBarcodeInfo");
    
    String numCyclesRead1 = null;
    
    for(int i = 0; i < barcodeInfo.length; i++)
    {
      Element barcodeInfoElement = barcodeInfo[i].toXML(doc);
      
      if(numCyclesRead1 == null)
        numCyclesRead1 = barcodeInfo[i].numCyclesRead1;
      
      Element barcodeName = doc.createElement("LaneBarcode");
      barcodeName.setAttribute("Name", barcodeInfo[i].laneBarcode);
      LaneBarcodeInfo.appendChild(barcodeInfoElement);
      LaneBarcodeList.appendChild(barcodeName);
    }
    
    root.setAttribute("Name", fcName);
    root.setAttribute("Type", barcodeInfo[0].fcType);
    if(numCyclesRead1 != null)
      root.setAttribute("NumCycles", numCyclesRead1);
    root.appendChild(LaneBarcodeList);
    root.appendChild(LaneBarcodeInfo);
    doc.appendChild(root);
    
    TransformerFactory transfac = TransformerFactory.newInstance();
    Transformer trans = transfac.newTransformer();
    trans.setOutputProperty(OutputKeys.OMIT_XML_DECLARATION, "no");
    trans.setOutputProperty(OutputKeys.INDENT, "yes");
    StringWriter sw = new StringWriter();
    StreamResult result = new StreamResult(sw);
    DOMSource source = new DOMSource(doc);
    trans.transform(source, result);
    String xmlString = sw.toString();
//    System.out.println("XML STRING");
//    System.out.println(xmlString);
    writer.write(xmlString);
    writer.close();
  }
  
  /**
   * Print the usage information
   */
  private static void printUsage()
  {
    System.err.print("Utility to download the flowcell plan from LIMS and write");
    System.err.println(" an XML file");
    System.err.println();
    System.err.println("Usage. Specify the following commannd line parameters :");
    System.err.println();
    System.err.println("DBName FCName OutputFile");
    System.err.println("  DBName      : LIMS database name");
    System.err.println("  FCName      : Flowcell name");
    System.err.println("  OutputFile  : Name of XML file to create");
  }
  
  /**
   * Main function
   * @param args
   */
  public static void main(String args[])
  {
    if(args.length != 3)
    {
      printUsage();
      System.exit(-1);
    }
    try
    {
      FlowcellPlanBuilder builder = new FlowcellPlanBuilder(args[0], args[1], args[2]);
      builder.process();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
    }
  }
}
