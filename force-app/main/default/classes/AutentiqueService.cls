/**
 * Serviço de integração com a plataforma Autentique para assinatura eletrônica.
 */
public with sharing class AutentiqueService {

    private static final String AUTENTIQUE_CONFIG_OBJECT = 'Autentique_Integration__c';
    private static final String AUTENTIQUE_DEFAULT_BASE_URL = 'https://api.autentique.com.br';
    private static final String AUTENTIQUE_DEFAULT_GRAPHQL_PATH = '/v2/graphql';
    private static final String EMAIL_REGEX = '^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$';
    private static final String PDF_CONTENT_TYPE = 'application/pdf';
    private static final String HTML_CONTENT_TYPE = 'text/html; charset=UTF-8';
    private static final String PDF_FILE_NAME = 'contrato.pdf';
    private static final String HTML_FILE_NAME = 'contrato.html';

    @AuraEnabled
    public static AutentiqueSendResult sendDocumentToAutentique(
        String opportunityId,
        String signerName,
        String signerEmail
    ) {
        if (String.isBlank(opportunityId)) {
            throw new GoogleDocsException('Informe a oportunidade para envio ao Autentique.');
        }
        if (!isValidEmail(signerEmail)) {
            throw new GoogleDocsException('Informe um e-mail válido para o signatário.');
        }

        String googleDocUrl = GoogleDocsService.createDocumentFromOpportunity(opportunityId);
        String docId = GoogleDocsService.extractDocumentIdFromUrl(googleDocUrl);
        String accessToken = GoogleAuthService.refreshAccessToken();
        AutentiqueFilePayload filePayload = buildAutentiqueFilePayload(accessToken, docId);

        String documentName = buildAutentiqueDocumentName(opportunityId);
        AutentiqueApiConfig cfg = getAutentiqueApiConfig();
        AutentiqueSendResult result = createAutentiqueDocument(
            cfg,
            filePayload,
            documentName,
            signerName,
            signerEmail
        );

        result.googleDocUrl = googleDocUrl;
        if (String.isBlank(result.message)) {
            result.message = 'Documento enviado ao Autentique com sucesso.';
        }
        return result;
    }

    private static String buildAutentiqueDocumentName(String opportunityId) {
        Opportunity opp = [
            SELECT Name, Account.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];
        String accountName = opp.Account != null ? opp.Account.Name : '';
        if (String.isBlank(accountName)) {
            return 'Contrato - ' + opp.Name;
        }
        return 'Contrato - ' + accountName + ' - ' + opp.Name;
    }

    private static AutentiqueFilePayload buildAutentiqueFilePayload(String accessToken, String documentId) {
        try {
            Blob pdfContent = GoogleDocsService.exportGoogleDocumentAsPdf(accessToken, documentId);
            return new AutentiqueFilePayload(PDF_FILE_NAME, PDF_CONTENT_TYPE, pdfContent);
        } catch (Exception ignored) {
            // Fallback para HTML se o export para PDF falhar em algum cenário específico.
        }

        String htmlContent = GoogleDocsService.exportGoogleDocumentAsHtml(accessToken, documentId);
        Blob htmlBlob = Blob.valueOf(htmlContent);
        return new AutentiqueFilePayload(HTML_FILE_NAME, HTML_CONTENT_TYPE, htmlBlob);
    }

    private static AutentiqueApiConfig getAutentiqueApiConfig() {
        Schema.SObjectType cfgType = Schema.getGlobalDescribe().get(AUTENTIQUE_CONFIG_OBJECT);
        if (cfgType == null) {
            throw new GoogleDocsException(
                'Configuração ausente. Crie a Custom Setting Hierarchy "Autentique_Integration__c".'
            );
        }

        String soql =
            'SELECT Is_Enabled__c, Base_Url__c, Graphql_Path__c, Api_Token__c ' +
            'FROM ' + AUTENTIQUE_CONFIG_OBJECT + ' ' +
            'WHERE SetupOwnerId = \'' + String.escapeSingleQuotes(UserInfo.getOrganizationId()) + '\' ' +
            'LIMIT 1';

        List<SObject> rows;
        try {
            rows = Database.query(soql);
        } catch (Exception e) {
            throw new GoogleDocsException(
                'Custom Setting inválida. Campos esperados: Is_Enabled__c, Base_Url__c, Graphql_Path__c, Api_Token__c.'
            );
        }

        if (rows.isEmpty()) {
            throw new GoogleDocsException(
                'Custom Setting Autentique_Integration__c sem registro de nível de organização.'
            );
        }

        SObject row = rows[0];
        AutentiqueApiConfig cfg = new AutentiqueApiConfig();
        cfg.enabled = (Boolean) row.get('Is_Enabled__c');
        cfg.baseUrl = (String) row.get('Base_Url__c');
        cfg.graphqlPath = (String) row.get('Graphql_Path__c');
        cfg.apiToken = (String) row.get('Api_Token__c');

        if (cfg.enabled == null) cfg.enabled = true;
        if (String.isBlank(cfg.baseUrl)) cfg.baseUrl = AUTENTIQUE_DEFAULT_BASE_URL;
        if (String.isBlank(cfg.graphqlPath)) cfg.graphqlPath = AUTENTIQUE_DEFAULT_GRAPHQL_PATH;

        if (!cfg.enabled) {
            throw new GoogleDocsException('Integração com Autentique está desativada na configuração.');
        }
        if (String.isBlank(cfg.apiToken)) {
            throw new GoogleDocsException('Api_Token__c não configurado na Autentique_Integration__c.');
        }
        return cfg;
    }

    private static AutentiqueSendResult createAutentiqueDocument(
        AutentiqueApiConfig cfg,
        AutentiqueFilePayload filePayload,
        String documentName,
        String signerName,
        String signerEmail
    ) {
        String mutation =
            'mutation CreateDocumentMutation($document: DocumentInput!, $signers: [SignerInput!]!, $file: Upload!) {' +
            ' createDocument(document: $document, signers: $signers, file: $file) {' +
            '  id name signatures { public_id name email link { short_link } }' +
            ' }' +
            '}';

        Map<String, Object> signer = new Map<String, Object>{
            'email' => signerEmail != null ? signerEmail.trim() : '',
            'action' => 'SIGN',
            'name' => String.isNotBlank(signerName) ? signerName.trim() : signerEmail
        };

        Map<String, Object> variables = new Map<String, Object>{
            'document' => new Map<String, Object>{ 'name' => documentName },
            'signers' => new List<Object>{ signer },
            'file' => null
        };

        Map<String, Object> operations = new Map<String, Object>{
            'query' => mutation,
            'variables' => variables
        };

        Map<String, Object> mapPart = new Map<String, Object>{
            'file' => new List<Object>{ 'variables.file' }
        };

        String boundary = '----AutentiqueBoundary' + String.valueOf(DateTime.now().getTime());
        String endpoint = joinUrl(cfg.baseUrl, cfg.graphqlPath);
        Blob multipartBody = buildMultipartBody(boundary, operations, mapPart, filePayload);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Authorization', 'Bearer ' + cfg.apiToken.trim());
        req.setHeader('Accept', 'application/json');
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(multipartBody);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new GoogleDocsException('Autentique retornou erro: ' + res.getBody());
        }

        Map<String, Object> responseJson =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (responseJson.containsKey('errors')) {
            List<Object> errors = (List<Object>) responseJson.get('errors');
            if (errors != null && !errors.isEmpty()) {
                Map<String, Object> firstError = (Map<String, Object>) errors[0];
                throw new GoogleDocsException('Autentique: ' + String.valueOf(firstError.get('message')));
            }
            throw new GoogleDocsException('Autentique retornou erro sem detalhes.');
        }

        Map<String, Object> data = (Map<String, Object>) responseJson.get('data');
        if (data == null || !data.containsKey('createDocument')) {
            throw new GoogleDocsException('Resposta do Autentique inválida.');
        }

        Map<String, Object> doc = (Map<String, Object>) data.get('createDocument');
        AutentiqueSendResult result = new AutentiqueSendResult();
        result.autentiqueDocumentId = String.valueOf(doc.get('id'));
        result.documentName = String.valueOf(doc.get('name'));
        result.signerEmail = signerEmail;

        List<Object> signatures = (List<Object>) doc.get('signatures');
        if (signatures != null && !signatures.isEmpty()) {
            Map<String, Object> firstSignature = (Map<String, Object>) signatures[0];
            result.signerPublicId = String.valueOf(firstSignature.get('public_id'));
            if (firstSignature.containsKey('link')) {
                Map<String, Object> link = (Map<String, Object>) firstSignature.get('link');
                if (link != null) {
                    result.signatureLink = String.valueOf(link.get('short_link'));
                }
            }
        }
        return result;
    }

    /**
     * Monta o corpo multipart/form-data conforme graphql-multipart-request-spec.
     * Usa concatenação via hex para evitar corrupção do binário (base64 com padding
     * quebrado corrompe o PDF e causa "failed_to_upload" na API Autentique).
     */
    private static Blob buildMultipartBody(
        String boundary,
        Map<String, Object> operations,
        Map<String, Object> mapPart,
        AutentiqueFilePayload filePayload
    ) {
        if (filePayload == null || filePayload.content == null || filePayload.content.size() == 0) {
            throw new GoogleDocsException('Arquivo para envio ao Autentique está vazio.');
        }

        String fileHeader = '';
        fileHeader += '--' + boundary + '\r\n';
        fileHeader += 'Content-Disposition: form-data; name="operations"\r\n\r\n';
        fileHeader += JSON.serialize(operations) + '\r\n';
        fileHeader += '--' + boundary + '\r\n';
        fileHeader += 'Content-Disposition: form-data; name="map"\r\n\r\n';
        fileHeader += JSON.serialize(mapPart) + '\r\n';
        fileHeader += '--' + boundary + '\r\n';
        fileHeader += 'Content-Disposition: form-data; name="file"; filename="' + filePayload.fileName + '"\r\n';
        fileHeader += 'Content-Type: ' + filePayload.contentType + '\r\n\r\n';

        String fileFooter = '\r\n--' + boundary + '--';

        Blob headerBlob = Blob.valueOf(fileHeader);
        Blob footerBlob = Blob.valueOf(fileFooter);

        String combinedHex =
            EncodingUtil.convertToHex(headerBlob) +
            EncodingUtil.convertToHex(filePayload.content) +
            EncodingUtil.convertToHex(footerBlob);

        return EncodingUtil.convertFromHex(combinedHex);
    }

    private static String joinUrl(String baseUrl, String path) {
        String b = baseUrl != null ? baseUrl.trim() : '';
        String p = path != null ? path.trim() : '';
        if (String.isBlank(p)) return b;
        Boolean bEnds = b.endsWith('/');
        Boolean pStarts = p.startsWith('/');
        if (bEnds && pStarts) return b.substring(0, b.length() - 1) + p;
        if (!bEnds && !pStarts) return b + '/' + p;
        return b + p;
    }

    private static Boolean isValidEmail(String email) {
        if (String.isBlank(email)) return false;
        return Pattern.matches(EMAIL_REGEX, email.trim().toLowerCase());
    }

    private class AutentiqueFilePayload {
        public String fileName;
        public String contentType;
        public Blob content;

        public AutentiqueFilePayload(String fileName, String contentType, Blob content) {
            this.fileName = fileName;
            this.contentType = contentType;
            this.content = content;
        }
    }

    public class AutentiqueSendResult {
        @AuraEnabled public String autentiqueDocumentId;
        @AuraEnabled public String documentName;
        @AuraEnabled public String signerPublicId;
        @AuraEnabled public String signatureLink;
        @AuraEnabled public String signerEmail;
        @AuraEnabled public String googleDocUrl;
        @AuraEnabled public String message;
    }

    private class AutentiqueApiConfig {
        public Boolean enabled;
        public String baseUrl;
        public String graphqlPath;
        public String apiToken;
    }
}
