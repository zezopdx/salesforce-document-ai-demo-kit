/**
 * @description Invocable Apex class that calls a pre-configured Document AI schema in Data 360.
 * It performs a single, direct call to the extract-data API endpoint using the provided schema name.
 * This is recommended for documents with known, consistent structures.
 *
 * @version 1.0
 * @see https://developer.salesforce.com/docs/data/connectapi/references/spec?meta=postDocumentAlConfigExtractData
 */
public with sharing class ConfiguredSchemaExtractor {

    // --- Input variables required from the Flow ---
    public class DocumentRequest {
        @InvocableVariable(label='Content Document ID' description='The ID of the Salesforce File (ContentDocument) to process.' required=true)
        public Id contentDocumentId;
        
        @InvocableVariable(label='Configuration API Name' description='The API Name of the pre-configured Document AI schema to use.' required=true)
        public String configurationName;
        
        @InvocableVariable(label='Named Credential' description='API Name of the Named Credential for the Data 360 endpoint.' required=true)
        public String namedCredentialName;
    }

    // --- Output variables returned to the Flow ---
    public class DocumentResult {
        @InvocableVariable(label='Extracted JSON Data' description='The JSON data extracted from the document.')
        public String extractedJson;
        
        @InvocableVariable(label='Error Message' description='Error message if the process failed.')
        public String errorMessage;
        
        @InvocableVariable(label='Is Success' description='True if the process completed successfully.')
        public Boolean isSuccess;
    }

    // --- Wrapper classes for deserializing the API response ---
    private class ExtractDataResponse {
        public List<ExtractionResult> data;
        public String error;
    }
    private class ExtractionResult {
        public String data; // This contains the inner, encoded JSON string of extracted data
        public String error;
    }

    @InvocableMethod(label='Extract Data with Pre-configured Schema' description='Extracts data from a document using a named Document AI configuration.')
    public static List<DocumentResult> extractData(List<DocumentRequest> requests) {
        DocumentRequest request = requests[0];
        DocumentResult result = new DocumentResult();

        try {
            // Check for FLS on ContentVersion before querying
            if (!Schema.sObjectType.ContentVersion.isAccessible()) {
                throw new SecurityException('Insufficient permissions to access ContentVersion object.');
            }
            
            // Get the file data from the ContentDocument ID
            ContentVersion cv = [SELECT VersionData, FileExtension FROM ContentVersion WHERE ContentDocumentId = :request.contentDocumentId AND IsLatest = true LIMIT 1];
            
            // Prepare the HTTP request
            HttpRequest req = new HttpRequest();
            // Use the Named Credential provided by the Flow
            req.setEndpoint('callout:' + request.namedCredentialName + '/services/data/v64.0/ssot/document-processing/actions/extract-data');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); // 2-minute timeout

            // Build the request body for the extract-data API
            Map<String, Object> filePayload = new Map<String, Object>{
                'data' => EncodingUtil.base64Encode(cv.VersionData), // Base64 encoded file data 
                'mimeType' => getMimeTypeFromExtension(cv.FileExtension) // File MIME type 
            };
        
            Map<String, Object> bodyMap = new Map<String, Object>{
                'idpConfigurationIdOrName' => request.configurationName, // Use the schema API name from the Flow input 
                'files' => new List<Object>{ filePayload } // Array containing the file payload 
            };
            
            req.setBody(JSON.serialize(bodyMap));
            
            // Send the request and process the response
            HttpResponse res = new Http().send(req);

            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) { // Check for successful HTTP status
                // Deserialize the outer response structure
                ExtractDataResponse responseWrapper = (ExtractDataResponse) JSON.deserialize(res.getBody(), ExtractDataResponse.class); 
                
                if (responseWrapper.data != null && !responseWrapper.data.isEmpty()) {
                    // Get the first result (usually only one file is processed)
                    ExtractionResult extraction = responseWrapper.data[0];
                    String innerData = extraction.data; // This is the string containing the actual JSON data 
                    
                    if (String.isNotBlank(innerData)) {
                        // Unescape HTML entities (like &quot;) before returning to Flow
                        result.extractedJson = innerData.unescapeHtml4(); 
                    } else {
                        result.extractedJson = null; // Handle case where extraction succeeded but no data found
                    }
                } else {
                    result.extractedJson = null;
                }
                result.isSuccess = true;
            } else {
                result.isSuccess = false;
                result.errorMessage = 'Data Extraction Failed. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody();
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage() + ' | Stack Trace: ' + e.getStackTraceString();
        }

        // Return the result list (required format for Invocable Methods)
        return new List<DocumentResult>{ result };
    }

    // --- Helper method to determine the file's MIME type ---
    private static String getMimeTypeFromExtension(String extension) {
        if (String.isBlank(extension)) { 
            return 'application/octet-stream'; 
        }
        String ext = extension.toLowerCase();
        if (ext == 'pdf') { return 'application/pdf'; }
        if (ext == 'png') { return 'image/png'; }
        if (ext == 'jpg' || ext == 'jpeg') { return 'image/jpeg'; }
        
        // Default for unknown types
        return 'application/octet-stream';
    }
}