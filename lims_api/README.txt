The collection of jars in this directories encapsulate the communication with
LIMS to download the flowcell information for analysis, upload the results and
other related functions.

These tools can work with multiple instances of LIMS databases (e.g. HGSC, WGL
etc) with the assumption that only the LIMS URL may be different for different
services, while keeping identical names of JSP pages and identical format of
query strings. The caller	MUST specify the database name to use and it must
match exactly one line in the config file LimsInfo.config. To make these tools
work with more instances of LIMS databases, add suitable entries to this config
file.

FlowcellPlanDownloader.jar : obtains the required information for analyzing
the flowcells from LIMS. It write an XML file describing the flowcell plan
into the specified location. 

Internally, it makes two HTTP requests :

http://lims_server_ip:port/getFlowCellInfo.jsp?flowcell_barcode=flowcellname

http://lims_server_ip:port/getAnalysisPreData.jsp?lane_barcode=flowcell-lane-barcode

AnalysisResultUploader.jar : pushes the analysis results for a given lane
barcode. Analysis results can be one of SEQUENCE_FINISHED (sequence generation
complete), ANALYSIS_FINISHED (alignment complete), UNIQUE_PERCENT_FINISHED
(unique percentage calculation finished) and CAPTURE_FINISHED (capture stats
calculation finished).

Internally, it makes one HTTP request depending on the type of results to
push:

For non-capture reults:

http://lims_server_ip:port/setIlluminaLaneStatus.jsp?lane_barcode=fc-lane-barcode&status=NewState&key1=value1&key2=value2...

For capture results:

http://lims_server_ip:port/setIlluminaCaptureResults.jsp?lane_barcode=fc-lane-barcode&status=NewState&key1=value1&key2=value2...

key value pairs are the parameter names and their corresponding values that
should be uploaded to LIMS.
