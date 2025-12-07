/**
 * @description This class provides a dynamic, invocable method to process any document 
 * with Document AI. It performs a two-step process:
 * 1. Dynamically generates a schema based on the document's content.
 * 2. Extracts the data from the document using the newly generated schema.
 * This allows for processing various document types without pre-configured schemas.
 *
 * v3.0: Upgraded to use typed wrapper classes for robust JSON deserialization.
 *
 * @see https://developer.salesforce.com/docs/data/connectapi/references/spec?meta=postDocumentAlGenerateSchema (For Schema Generation)
 * @see https://developer.salesforce.com/docs/data/connectapi/references/spec?meta=postDocumentAlConfigExtractData (For Data Extraction)
 */
public with sharing class DynamicDocumentAIProcessor {

    // --- Invocable Method Input/Output Classes ---
    public class DocumentRequest {
        @InvocableVariable(label='Content Document ID' description='The ID of the Salesforce File (ContentDocument) to process.' required=true)
        public Id contentDocumentId;
        @InvocableVariable(label='ML Model Name' description='API Name of the LLM to use.' required=true)
        public String mlModelName;
        @InvocableVariable(label='Named Credential' description='API Name of the Named Credential for the Data Cloud endpoint.' required=true)
        public String namedCredentialName;
    }
    public class DocumentResult {
        @InvocableVariable(label='Extracted JSON Data' description='The JSON data extracted from the document.')
        public String extractedJson;
        @InvocableVariable(label='Generated Schema' description='The schema that was dynamically generated for the document.')
        public String generatedSchema;
        @InvocableVariable(label='Error Message' description='Error message if the process failed.')
        public String errorMessage;
        @InvocableVariable(label='Is Success' description='True if the process completed successfully.')
        public Boolean isSuccess;
    }

    // --- Helper and Wrapper Classes ---
    private class CalloutParameters {
        String fileAsBase64;
        String mimeType;
        String mlModelName;
        String namedCredentialName;
        String schemaConfig;
    }

    // *** NEW: Wrapper class for the generate-schema API response ***
    private class GenerateSchemaResponse {
        public String schema;
        public String error;
    }

    // *** NEW: Wrapper classes for the extract-data API response ***
    private class ExtractDataResponse {
        public List<ExtractionResult> data;
        public String error;
    }
    private class ExtractionResult {
        public String data; // This contains the inner, encoded JSON string of extracted data
        public String error;
    }

    @InvocableMethod(label='Process Document with Dynamic AI' description='Generates a schema and extracts data from a document dynamically.')
    public static List<DocumentResult> processDocument(List<DocumentRequest> requests) {
        // ... main logic is the same, calls the refactored helper methods
        List<DocumentResult> results = new List<DocumentResult>();
        DocumentRequest request = requests[0];
        DocumentResult result = new DocumentResult();
        try {
            if (!Schema.sObjectType.ContentVersion.isAccessible()) {
                throw new SecurityException('Insufficient permissions to access ContentVersion.');
            }
            ContentVersion cv = [SELECT VersionData, FileExtension FROM ContentVersion WHERE ContentDocumentId = :request.contentDocumentId AND IsLatest = true LIMIT 1];
            CalloutParameters params = new CalloutParameters();
            params.fileAsBase64 = EncodingUtil.base64Encode(cv.VersionData);
            params.mimeType = getMimeTypeFromExtension(cv.FileExtension);
            params.mlModelName = request.mlModelName;
            params.namedCredentialName = request.namedCredentialName;

            String encodedSchemaJson = generateSchema(params);
            if (String.isNotBlank(encodedSchemaJson)) {
                String decodedSchemaJson = encodedSchemaJson.unescapeHtml4();
                result.generatedSchema = decodedSchemaJson;
                params.schemaConfig = decodedSchemaJson;
                String extractedData = extractData(params);
                result.extractedJson = extractedData;
                result.isSuccess = true;
            } else {
                throw new CalloutException('Schema generation returned an empty or null response.');
            }
        } catch (Exception e) {
            result.isSuccess = false;
            result.errorMessage = e.getMessage() + ' | Stack Trace: ' + e.getStackTraceString();
        }
        results.add(result);
        return results;
    }
    
    private static String getMimeTypeFromExtension(String extension) {
        // ... this helper method remains the same
        if (String.isBlank(extension)) { return 'application/octet-stream'; }
        String ext = extension.toLowerCase();
        if (ext == 'pdf') { return 'application/pdf'; }
        else if (ext == 'png') { return 'image/png'; }
        else if (ext == 'jpg' || ext == 'jpeg') { return 'image/jpeg'; }
        else { return 'application/octet-stream'; }
    }
    
    // *** UPDATED: Now uses the GenerateSchemaResponse wrapper class ***
    private static String generateSchema(CalloutParameters params) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + params.namedCredentialName + '/services/data/v64.0/ssot/document-processing/actions/generate-schema');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000); // 120 seconds for schema generation
        Map<String, Object> bodyMap = new Map<String, Object>{'mlModel' => params.mlModelName, 'files' => new List<Object>{new Map<String, Object>{'data' => params.fileAsBase64, 'mimeType' => params.mimeType}}};
        req.setBody(JSON.serialize(bodyMap));
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            GenerateSchemaResponse responseWrapper = (GenerateSchemaResponse) JSON.deserialize(res.getBody(), GenerateSchemaResponse.class);
            return responseWrapper.schema;
        } else {
            throw new CalloutException('Schema Generation Failed. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
    }

    // *** UPDATED: Now uses the ExtractDataResponse wrapper classes ***
    private static String extractData(CalloutParameters params) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + params.namedCredentialName + '/services/data/v64.0/ssot/document-processing/actions/extract-data');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000); // 120 seconds for data extraction
        Map<String, Object> bodyMap = new Map<String, Object>{'mlModel' => params.mlModelName, 'schemaConfig' => params.schemaConfig, 'files' => new List<Object>{new Map<String, Object>{'data' => params.fileAsBase64, 'mimeType' => params.mimeType}}};
        req.setBody(JSON.serialize(bodyMap));
        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
            ExtractDataResponse responseWrapper = (ExtractDataResponse) JSON.deserialize(res.getBody(), ExtractDataResponse.class);
            if (responseWrapper.data != null && !responseWrapper.data.isEmpty()) {
                // The actual extracted data is in the 'data' property of the first list item
                return responseWrapper.data[0].data;
            }
            return null;
        } else {
            throw new CalloutException('Data Extraction Failed. Status: ' + res.getStatusCode() + ' Body: ' + res.getBody());
        }
    }
}