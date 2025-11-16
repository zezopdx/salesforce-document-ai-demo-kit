# salesforce-document-ai-demo-kit
Apex classes and instructions for building Document AI demos in Salesforce.

# Salesforce Document AI Demo Kit

This repository contains the necessary Apex classes, configuration, and instructions to build a demonstration of Salesforce Document AI integrated with Data 360.

This pattern uses a pre-configured Document AI schema and a set of Apex classes to perform the callout and parse the complex JSON response, making the data simple to use in a Screen Flow.

## Demo Components

### ⚙️ Apex Classes
* [src/classes/ConfiguredSchemaExtractor.cls](src/classes/ConfiguredSchemaExtractor.cls): A reusable, invocable Apex action. It calls the Data Cloud `extract-data` API using a Named Credential and the API name of a pre-configured schema.
* [src/classes/InsuranceCardJsonParser.cls](src/classes/InsuranceCardJsonParser.cls): An invocable Apex action that parses an insurance card and outputs variables that can be used in a Flow (i.e. `insuredMember`, 'insuranceCompany'). Can be used as a reference or template to configure other JSON parser classes specific to your configured schemas (`Invoices`, `Loan Applications`, etc).

### Example Schemas
* [Commercial Loan](https://docs.google.com/spreadsheets/d/1rSXhexIqaf5CSSv5Qwh0AqPpx9wnZ4H19wcvKRrUREg/edit?gid=1355363628#gid=1355363628)
* [Insurance Card](https://docs.google.com/spreadsheets/d/16g4IdUS-lsgbB17HVGlP5ZI9hEM-IpZWNgiqSkTuL3M/edit?gid=1991087831#gid=1991087831)

---

## Setup Guide

Follow these steps to build the demo in your own org.

### Step 1: API Setup
Confirm you have a `Connected App` that can call Data 360 APIs. Use the `Connected App` to create an `Auth. Provider` and a `Named Credential` to use in the Apex Class. If this is not available in your org, follow the instructions below. 

1. Create and download a self-signed certificate:
    1. Setup > Certificate and Key Management > click Create Self-Signed Certificate > label it as `DataCloudCert` > key size: 2048 > Save > Download the cert (should have a .crt extension)
2. Create a Connected App
    1. Setup > Search `External Client Apps` and click Settings under that > if it's not already enabled, enable `Allow creation of connected apps` & `Allow access to External Client App consumer secrets via REST API` > Click `New Connected App`
        1. Name it `DataCloudAPI`
        2. Enter your email for contact email
        3. Check the box: `Enable OAuth Settings`
        4. Callback URL: `https://login.salesforce.com` (we'll change this later, for now make sure it starts with `https://`)
        5. Check the box: `Use digital signatures` and upload the cert from Step 1
        6. For `Selected OAuth Scopes` - select the following:
            1. Access the identity URL service (id, profile, email, address, phone)
            2. Manage user data via APIs (api)
            3. Manage user data via Web browsers (web)
            4. Full access (full)
            5. Perform requests at any time (refresh_token, offline_access)
            6. Access unique user identifiers (openid)
            7. Access Lightning applications (lightning)
            8. Access content resources (content)
            9. Manage Data Cloud Ingestion API data (cdp_ingest_api)
            10. Manage Data Cloud profile data (cdp_profile_api)
            11. Perform ANSI SQL queries on Data Cloud data (cdp_query_api)
            12. Access chatbot services (chatbot_api)
            13. Perform segmentation on Data Cloud data (cdp_segment_api)
            14. Manage Data Cloud Identity Resolution (cdp_identityresolution_api)
            15. Manage Data Cloud Calculated Insight data (cdp_calculated_insight_api)
            16. Access the Salesforce API Platform (sfap_api)
            17. Access all Data Cloud API resources (cdp_api)
            18. Access Einstein GPT services (einstein_gpt_api)
        7. Make sure `Require Secret for Web Server Flow` is checked, leave the rest of the defaults on.
        8. Save and continue
        9. Find and copy the `Consumer Key` and `Consumer Secret`, save them in your notes to use later.
        10. Click `Manage` on the connected app you just created.
        11. Under `OAuth Policies`, set `Permitted Users` to `Admin approved users are pre-authorized` > Save
        12. Scroll down to the Profiles > add System Admin (assuming you're logged in as the Admin setting this up)
3. Create `Auth. Provider`
    1. Setup > Auth. Provider > click New > Name it `Data_Cloud_Auth_Provider` > leave the URL suffix as default > Provider: Salesforce > copy over the `Consumer Key` and `Consumer Secret` from the Connected App setup > Default scopes: `cdp_api refresh_token api` > Click Save
    2. After you hit save, at the bottom of the screen you should see the "Salesforce Configuration" section. find and copy the `Callback URL`. Go back to the connected app you created and step 2 (Setup > App Manager > DataCloudAPI > click on drop down menu and click Edit) > update the Callback URL from https://login.salesforce.com to the callback URL you copied from the Auth. Provider (Data_Cloud_Auth_Provider)
4. Create the `Named Credential`
    1. Go to Setup > `My Domain` > copy the link next to "Current My Domain URL", save in your notes to use later.
    2. Setup > `Named Credential` > In the New drop down, click `New Legacy` > label: Data Cloud API > leave name as default, make sure it's Data_Cloud_API as we'll reference this later in the Flow. > URL: paste your `My Domain URL` and make sure it starts with `https://` > Identity Type: `Named Principal` > Auth Protocol: `OAuth 2.0` > Auth Provider: `Data_Cloud_Auth_Provider` > Scope: `cdp_api refresh_token api` > Make sure this box is checked: `Start Authentication Flow` on Save > Click Save.
        1. You will be redirected to a Salesforce login screen. Log in as the admin user you pre-authorized in the Connected App. This performs the one-time OAuth handshake to generate the initial tokens. After authenticating, you will see the Authentication Status is Authenticated.
       
Now, API setup is complete. Nice work!

### Step 2: Configure Document AI in Data 360

1.  Go to the **Data Cloud** app.
2.  Click the **Process Content** tab.
3.  Click **Document AI** in the left navigation.
4.  Click **New**. For this demo, you can choose `Without a Source Object`
5.  Create your schema (e.g., `Commercial_Loan_Extraction_Schema`). You can define the fields manually (like `LenderName`, `PrincipalAmount`, `PrepaymentPenalty`) to match the fields in the.
    1. See example schema with field names, field types, and prompt instructions: `Insurance Card Schema`
7.  Feel free to test your schema with sample documents to confirm results. Then **Activate** your schema.

### Step 3: Deploy Apex Classes

Use the [src/classes/ConfiguredSchemaExtractor.cls](src/classes/ConfiguredSchemaExtractor.cls) Apex Class provided in this repo. This is configured to call Document AI with the following inputs: `Pre-configured Document AI Schema`, `File Id`, and a `Named Credential`.

You'll need another Apex Class to parse the extracted JSON so that it can be used in your Flow (which can then create or update records, trigger automation, ground Prompt Templates, etc.). Your JSON parser class should mirror the schema you created in Document AI.

Watch out for fields with data types other than Text or Numbers so you can update them accordingly in the Apex Class. For example, `applicationDate` will be defined as a `String` in your Document AI schema. In your JSON parser Apex Class, you'll need to define it as a `Date` or `DateTime` field type so your Flow can process it as a date field or use it to assign values to other date fields.

For reference, see the example JSON parser below:
[src/classes/InsuranceCardJsonParser.cls](src/classes/InsuranceCardJsonParser.cls)

### Step 4: Prepare Other Demo Assets

Create other components you'll want to use in the demo flow, such as Prompt Templates to leverage AI alongside the extracted data.

Example:
1. Create a new Prompt Template
   *Flex
   *Configure a Text Input, name it something like `extractedJson` -- this will infuse the Prompt Template with the extracted JSON from Document AI
2. Engineer your prompt to review the extracted JSON, analyze it, and provide your desired input.

See example below that summarizes a commercial loan agreement:
[src/prompts/LoanExecutiveSummary.txt](src/prompts/LoanExecutiveSummary.txt)

### Step 5: Build the Screen Flow

<img width="1715" height="961" alt="Screenshot 2025-11-15 at 5 09 25 PM" src="https://github.com/user-attachments/assets/8c02c347-e6be-4157-bf63-180e3fd10d07" />


Use the following elements to create a Screen Flow:

1.  **Screen (Upload):**
    * Add a **File Upload** component.
    * Set **API Name** to `file_uploader`.
    * Set **Accepted Formats** to `.pdf,.jpg,.jpeg,.png`
    * Set **Allow Multiple Files** to `False`
    * Set **Related Record ID** to `{!recordId}` (you can create the variable by clicking `New Resource` > **Resource Type**: `Variable` > **Data Type**: `Text` > check the box for `Available for Input`).

2.  **Loop:**
    * Loop through the Output from the `file_uploader` collection. This is necessary to get the ID of the single uploaded file. **Note**: even if you've set **Allow Multiple Files** to `False`, Flow will save the Id of your uploaded file in a collection variable. This loop will help extract the file's Id via the next step.

3.  **Assignment (inside Loop):**
    * Create a new **Text** variable called `vContentDocumentId`.
    * Assign `{!Loop_Element.CurrentItem}` to `{!vContentDocumentId}`.
    * *(This assignment ensures that after the loop finishes, the variable holds the ID of the last (and only) file.)*

4.  **Action (Extract):**
    * Add an **Action** element.
    * Search for and select **`Extract Data with Pre-configured Schema`** (`ConfiguredSchemaExtractor`).
    * **Label:** `Extract Data from File`
    * **Set Inputs:**
        * `configurationName`: Use the API name of the schema you created in Step 2 of this setup guide.
        * `contentDocumentId`: `{!vContentDocumentId}`
        * `namedCredentialName`: `Data_Cloud_API` (the `Named Credential` you created in Step 1 of this setup guide)

5.  **Action (Parse):**
    * Add an **Action** element.
    * Search for and select the JSON parser Apex Class you deployed in Step 3 of this setup guide.
    * **Label:** `Prepare data for review`
    * **Set Inputs:**
        * `jsonString`: `{!Extract_Data_from_File.extractedJson}`
    * You can use the Output Resources or manually assign variables.

6. **Incorporate other Demo Components:**
   * Add in any other elements (Create, Get, or Update Records) or Prompt Templates you want to use with the extracted data.

8.  **Screen (Review):**
    * Add a **Screen** element.
    * Add **Text Input**, **Number Input**, or **Display Text** components to review outputs.
    * Set the **Default Value** for each component using the variables from the previous step (e.g., Default Value for Borrower Name text box is `{!vBorrowerName}`) or use `promptResponse` in **Display Text** components.

9.  **Create Records (optional):**
    * Add a **Create Records** element.
    * Choose your relevant object.
    * Map the fields from the **Outputs of the Parse extracted JSON Action** to the related object fields.
  

# Disclaimer
This setup guide is for instructions and guidelines to create a Document AI demo. The sample code is delivered "as-is" to the user and was designed for demonstration purposes. Salesforce bears no responsibility to support the user or implementation of this software.
