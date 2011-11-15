package limsClient;

/**
 * Class to upload analysis results to LIMS.
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public class AnalysisResultUploader extends LIMSClient
{
  private String limsPage   = "setIlluminaLaneStatus.jsp";
  private String newState   = null; // New state to set in LIMS
  private String fcBarcode  = null; // Flowcell barcode for which result should be set
  
  // Collection of keys and values to be passed to LIMS
  private String[] keys   = null;
  private String[] values = null;
  
  /**
   * Class constructor
   * @param dbName
   * @param newState
   * @param fcBarcode
   * @param keyValPairs
   * @throws Exception
   */
  public AnalysisResultUploader(String dbName, String newState, 
         String fcBarcode, String keyValPairs[]) throws Exception
  {
    super(dbName);
    String tokens[];
    
    this.newState = newState;
    this.fcBarcode = fcBarcode;
    
    if(keyValPairs == null || keyValPairs.length < 1)
      throw new Exception("KeyValPairs cannot be null or empty");
    
    keys   = new String[keyValPairs.length];
    values = new String[keyValPairs.length];
    
    for(int i = 0; i < keyValPairs.length; i++)
    {
      tokens    = getKeyAndValue(keyValPairs[i]);
      keys[i]   = tokens[0];
      values[i] = tokens[1];
    }
  }

  /**
   * Overridden method to perform the actual action
   */
  @Override
  public void process()
  {
    String limsRequestURL = buildRequest();
    
    printInfo("Sending HTTP request " + limsRequestURL);
    
    try
    {
      boolean error = sendGETRequest(limsRequestURL);
    
      if(error)
      {
        printError("Error in uploading results to LIMS. Response : " + responseContent.toString());
        System.exit(-1);
      }
      else
      {
        printInfo("Results uploaded to LIMS. Response Message : " + responseContent.toString());
      }
    }
    catch(Exception e)
    {
      printError(e.getMessage());
      e.printStackTrace();
      System.exit(-1);
    }
  }
  
  /**
   * Given a key=Value string, split it and return Key and Value
   * @param keyValPair
   * @return
   * @throws Exception
   */
  private String[] getKeyAndValue(String keyValPair) throws Exception
  {
    String tokens[] = keyValPair.split("=");
    
    if(tokens.length != 2)
      throw new Exception(keyValPair + " is not a valid key value pair");
    return tokens;
  }
  
  /**
   * Method to build a request URL to send results to LIMS
   * @return
   */
  private String buildRequest()
  {
    StringBuffer completeURL = new StringBuffer(limsBaseURL + "/" + limsPage + "?");
    completeURL.append("lane_barcode=" + fcBarcode);
    completeURL.append("&status=" + newState);
    
    for(int i = 0; i < keys.length; i++)
    {
      completeURL.append("&key" + (i + 1) + "=" + keys[i]);
      completeURL.append("&value" + (i + 1) + "=" + values[i]);
    }
    return completeURL.toString();
  }
  
  /**
   * Print usage information
   */
  private static void printUsage()
  {
    System.err.println("Utility to push analysis results to LIMS");
    System.err.println();
    System.err.println("Usage. Specify the following commannd line parameters");
    System.err.println();
    System.err.println("DBName FCLaneBarcode NewState Key=value...");
    System.err.println("  DBName        : LIMS database name");
    System.err.println("  FCLaneBarcode : Flowcell Lane barcode");
    System.err.println("                  e.g. 70EMPAAXX-5-ID01");
    System.err.println("  NewState      : New result state");
    System.err.print("                  e.g. ANALYSIS_FINISHED, SEQUENCE_FINISHED");
    System.err.println(" UNIQUE_PERCENT_FINISHED");
    System.err.print("  Key=value     : Collection of key value pairs to be uploaded");
    System.err.println(" as results to LIMS");
  }
  
  /**
   * Main function
   * @param args
   */
  public static void main(String args[])
  {
    if(args.length < 4)
    {
      printUsage();
      System.exit(-1);
    }
    try
    {
      String keyValPairs[] = new String[args.length - 3];
      
      for(int i = 3; i < args.length; i++)
        keyValPairs[i - 3] = args[i];
      
      AnalysisResultUploader uploader = new AnalysisResultUploader(args[0], 
				                                args[1], args[2], keyValPairs);
      uploader.process();
    }
    catch(Exception e)
    {
      System.err.println(e.getMessage());
      e.printStackTrace();
      System.exit(-1);
    }
  }
}
