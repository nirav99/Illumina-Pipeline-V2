package limsClient;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.ProtocolException;
import java.net.URL;

enum Lims_Action
{
	GET_FLOWCELL_PLAN,
	UPLOAD_RESULTS
}

/**
 * Class to encapsulate HTTP communication with LIMS
 * @author Nirav Shah niravs@bcm.edu
 *
 */
public abstract class LIMSClient
{
  protected String limsBaseURL = null;           // Base URL for LIMS
  private String limsDB = null;                  // Which database to hit
  protected int responseCode = 0;                // HTTP Response code from LIMS
  protected StringBuffer responseContent = null; // Actual response content from LIMS
  
  /**
   * Class constructor
   * @param databaseName
   * @throws IOException
   * @throws Exception
   */
  public LIMSClient(String databaseName) throws IOException, Exception
  {
    limsDB = databaseName.toLowerCase();
    getLIMSBaseURLName();
  }
  
  /**
   * Helper method to get URL prefix name - this would be different for different
   * LIMS server instances (e.g. HGSC, WGL etc).
   * @throws IOException
   * @throws Exception
   */
  private void getLIMSBaseURLName() throws IOException, Exception
  {
    InputStream is = getClass().getResourceAsStream("LimsInfo.config");
    BufferedReader reader = new BufferedReader(new InputStreamReader(is));
//    BufferedReader reader = new BufferedReader(new FileReader("LimsInfo.config"));
    
    String line = null;
    
    while((line = reader.readLine()) != null)
    {
      if(line.startsWith(limsDB.toLowerCase() + "=") ||
         line.startsWith(limsDB.toUpperCase() + "="))
      {
        limsBaseURL = line.substring(line.indexOf('=') + 1);
        System.out.println("LIMS Base URL : " + limsBaseURL);
      }
    }
    reader.close();
    
    if(limsBaseURL == null)
      throw new Exception("Error: LIMS base URL not defined for " + limsDB);    
  }
  
  /**
   * Method to perform the required action
   */
  public abstract void process();
  
  /**
   * Helper method to send GET request to LIMS
   * @param completeURL
   * @throws Exception
   */
  protected boolean sendGETRequest(String completeURL) throws Exception
  {
    boolean errorOccurred = false;
    long startTime, endTime;
   
    URL limsURL = new URL(completeURL);
    HttpURLConnection connection = (HttpURLConnection)limsURL.openConnection();
    connection.setRequestMethod("GET");

    startTime = System.currentTimeMillis();
    connection.connect();
    responseCode = connection.getResponseCode();
    
    BufferedReader reader = new BufferedReader(new InputStreamReader(connection.getInputStream()));
    responseContent = null;
    responseContent = new StringBuffer();
    String line = null;
    
    while((line = reader.readLine()) != null)
    {
      responseContent.append(line);
      responseContent.append("\n");
    }
    endTime = System.currentTimeMillis();
    reader.close();

    printInfo("Round trip query time : " + (endTime - startTime));
    
    if(responseCode == 200 && responseContent.indexOf("Error") == -1 &&
       responseContent.indexOf("error") == -1)
    {
      printInfo("Resonse code 200, no error in response");
      printInfo(responseContent.toString());
    }
    else
    {
      printError("Error in HTTP Response. Response code : " + responseCode);
      printError("Repsonse :" + responseContent.toString());
      errorOccurred = true;
    }
    return errorOccurred;
  }
  
  /**
   * Log information - for now dump to stdout
   * @param s
   */
  protected void printInfo(String s)
  {
    System.out.println(s);
  }
  
  /**
   * Log errors - for now dump to stderr
   * @param s
   */
  protected void printError(String s)
  {
    System.err.println(s);
  }
}
