/**
 * @description Global, invocable bridge to parse an Insurance Card JSON payload for Flow.
 * v1.1 
 */
global with sharing class InsuranceCardJsonParser {

    // --- Input Class (No Change) ---
    global class Request {
        @InvocableVariable(required=true)
        @AuraEnabled
        public String json;
    }
    
    // --- THIS CLASS IS NO LONGER NEEDED ---
    // (You can delete the nested 'ParsedMember' class)
    // global class ParsedMember { ... } 

    /**
     * Output wrapper flattened for Flow variable assignment.
     */
    global class Response {
        @InvocableVariable @AuraEnabled public String carrierName;
        @InvocableVariable @AuraEnabled public String planName;
        @InvocableVariable @AuraEnabled public String groupNumber;
        @InvocableVariable @AuraEnabled public String memberId;
        @InvocableVariable @AuraEnabled public String payerNumber;
        @InvocableVariable @AuraEnabled public String memberServices;
        @InvocableVariable @AuraEnabled public String employerName;

        // Collection variable: List<InsuranceMember> ---
        @InvocableVariable @AuraEnabled public List<InsuranceMember> members;

        // Diagnostics
        @InvocableVariable @AuraEnabled public String errorMessage;
    }

    /**
     * Main entry point for Flow.
     */
    @InvocableMethod(label='Parse Insurance Card JSON' description='Parses Insurance Card JSON into flattened Flow variables.')
    global static List<Response> parse(List<Request> requests) {
        List<Response> results = new List<Response>();
        if (requests == null) return results;

        for (Request req : requests) {
            Response res = new Response();
            try {
                if (req == null || String.isBlank(req.json)) {
                    res.errorMessage = 'Empty request or JSON payload.';
                    results.add(res);
                    continue;
                }
                
                Map<String, Object> jsonMap = (Map<String, Object>) JSON.deserializeUntyped(req.json);
                
                if (jsonMap != null) {
                    res.carrierName = extractStringValue(jsonMap, 'carrierName');
                    res.planName = extractStringValue(jsonMap, 'planName');
                    res.groupNumber = extractStringValue(jsonMap, 'groupNumber');
                    res.memberId = extractStringValue(jsonMap, 'memberId');
                    res.payerNumber = extractStringValue(jsonMap, 'payerNumber');
                    res.memberServices = extractStringValue(jsonMap, 'memberServices');
                    res.employerName = extractStringValue(jsonMap, 'employerName');

                    // --- MODIFIED: Changed ParsedMember to InsuranceMember ---
                    res.members = new List<InsuranceMember>(); // Changed
                    List<Object> rawMembersList = extractArrayValue(jsonMap, 'members');

                    if (rawMembersList != null) {
                        for (Object memberObj : rawMembersList) {
                            if (memberObj instanceof Map<String, Object>) {
                                Map<String, Object> memberWrapper = (Map<String, Object>) memberObj;
                                // Unwrap nested { type, value } if present
                                Map<String, Object> memberMap;
                                if (memberWrapper.containsKey('value') && memberWrapper.get('value') instanceof Map<String, Object>) {
                                    memberMap = (Map<String, Object>) memberWrapper.get('value');
                                } else {
                                    memberMap = memberWrapper;
                                }
                                
                                // Changed
                                InsuranceMember parsedMember = new InsuranceMember(); 

                                parsedMember.memberSuffix = extractStringValue(memberMap, 'memberSuffix');
                                parsedMember.memberName = extractStringValue(memberMap, 'memberName');
                                parsedMember.pcpRequirement = extractStringValue(memberMap, 'pcpRequirement');
                                
                                res.members.add(parsedMember);
                            }
                        }
                    }
                }

            } catch (Exception e) {
                res.errorMessage = 'Parse error: ' + e.getMessage() + ' | Stack: ' + e.getStackTraceString();
            }
            results.add(res);
        }
        return results;
    }

    // ========== Helpers (support nested { type, value } shape) ==========
    
    private static String extractStringValue(Map<String, Object> jsonMap, String fieldName) {
        if (jsonMap == null || String.isBlank(fieldName)) {
            return null;
        }
        if (!jsonMap.containsKey(fieldName)) {
            return null;
        }
        Object value = jsonMap.get(fieldName);
        if (value == null) {
            return null;
        }
        // Handle nested { type, value }
        if (value instanceof Map<String, Object>) {
            Map<String, Object> wrapper = (Map<String, Object>) value;
            if (wrapper.containsKey('value')) {
                Object unwrappedValue = wrapper.get('value');
                if (unwrappedValue == null) return null;
                if (unwrappedValue instanceof String) return (String) unwrappedValue;
                if (unwrappedValue instanceof Boolean || unwrappedValue instanceof Integer || unwrappedValue instanceof Long ||
                    unwrappedValue instanceof Decimal || unwrappedValue instanceof Double || unwrappedValue instanceof Date ||
                    unwrappedValue instanceof Datetime || unwrappedValue instanceof Time) {
                    return String.valueOf(unwrappedValue);
                }
                return null;
            }
        }
        if (value instanceof String) {
            return (String) value;
        }
        // Fallback: convert primitives to String, ignore complex objects
        if (value instanceof Boolean || value instanceof Integer || value instanceof Long ||
            value instanceof Decimal || value instanceof Double || value instanceof Date ||
            value instanceof Datetime || value instanceof Time) {
            return String.valueOf(value);
        }
        return null;
    }
    
    private static List<Object> extractArrayValue(Map<String, Object> jsonMap, String fieldName) {
        if (jsonMap == null || String.isBlank(fieldName)) {
            return null;
        }
        if (!jsonMap.containsKey(fieldName)) {
            return null;
        }
        Object value = jsonMap.get(fieldName);
        if (value == null) {
            return null;
        }
        // Handle nested { type, value } where value is an array
        if (value instanceof Map<String, Object>) {
            Map<String, Object> wrapper = (Map<String, Object>) value;
            if (wrapper.containsKey('value') && wrapper.get('value') instanceof List<Object>) {
                return (List<Object>) wrapper.get('value');
            }
            return null;
        }
        if (value instanceof List<Object>) {
            return (List<Object>) value;
        }
        return null;
    }
}