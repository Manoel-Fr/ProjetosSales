/**
 * Serviço de integração com a plataforma Autentique para assinatura eletrônica.
 */
public with sharing class AutentiqueService {

    private static final String AUTENTIQUE_CONFIG_OBJECT = 'DatagoProjects__Autentique_Integration__c';
    private static final String AUTENTIQUE_DEFAULT_BASE_URL = 'https://api.autentique.com.br';
    private static final String AUTENTIQUE_DEFAULT_GRAPHQL_PATH = '/v2/graphql';
    private static final String EMAIL_REGEX = '^[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}$';

    public class SignerInput {
        @AuraEnabled public String name;
        @AuraEnabled public String email;
    }

    @AuraEnabled
    public static AutentiqueSendResult sendDocumentToAutentique(
        String opportunityId,
        String signersJson
    ) {
        if (String.isBlank(opportunityId)) {
            throw new GoogleDocsException('Informe a oportunidade para envio ao Autentique.');
        }
        if (String.isBlank(signersJson)) {
            throw new GoogleDocsException('Informe ao menos um signatário.');
        }
        List<SignerInput> signers;
        try {
            signers = (List<SignerInput>) JSON.deserialize(signersJson, List<SignerInput>.class);
        } catch (Exception e) {
            throw new GoogleDocsException('Formato de signatários inválido.');
        }
        if (signers == null || signers.isEmpty()) {
            throw new GoogleDocsException('Informe ao menos um signatário.');
        }
        for (SignerInput s : signers) {
            if (!isValidEmail(s.email)) {
                throw new GoogleDocsException('E-mail inválido: ' + s.email);
            }
        }

        Opportunity opp = [SELECT Name, Account.Name, Google_Doc_Url__c FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        String documentName = String.isNotBlank(opp.Account?.Name)
            ? 'Contrato - ' + opp.Account.Name + ' - ' + opp.Name
            : 'Contrato - ' + opp.Name;

        String accessToken = GoogleAuthService.refreshAccessToken();
        String googleDocUrl = String.isNotBlank(opp.Google_Doc_Url__c)
            ? opp.Google_Doc_Url__c
            : GoogleDocsService.createDocumentFromOpportunity(opportunityId);
        String docId = GoogleDocsService.extractDocumentIdFromUrl(googleDocUrl);
        AutentiqueFilePayload filePayload = buildAutentiqueFilePayload(accessToken, docId);

        AutentiqueApiConfig cfg = getAutentiqueApiConfig();
        AutentiqueSendResult result = createAutentiqueDocument(cfg, filePayload, documentName, signers);

        result.googleDocUrl = googleDocUrl;
        if (String.isBlank(result.message)) {
            result.message = 'Documento enviado ao Autentique com sucesso.';
        }

        update new Opportunity(
            Id = opportunityId,
            DatagoProjects__DocId__c = result.autentiqueDocumentId,
            DatagoProjects__AssEnv__c = true
        );

        List<Assinatura__c> assinaturas = new List<Assinatura__c>();
        // 1. Criador (quem enviou)
        User currentUser = [SELECT Name, Email FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        assinaturas.add(new Assinatura__c(
            AssOpp__c = opportunityId,
            AutDoc__c = result.autentiqueDocumentId,
            TpSign__c = 'Criador',
            NmSign__c = currentUser.Name,
            EmlAss__c = currentUser.Email,
            StsAss__c = 'Assinado',
            DtAssn__c = DateTime.now(),
            OrdAss__c = 0
        ));
        // 2. Signatários (um por cada)
        Map<String, SignerResultInternal> signerResultMap = new Map<String, SignerResultInternal>();
        for (SignerResultInternal sr : result.allSignerResults) {
            signerResultMap.put(sr.email?.toLowerCase(), sr);
        }
        for (Integer i = 0; i < signers.size(); i++) {
            SignerInput s = signers[i];
            SignerResultInternal sr = signerResultMap.get(s.email?.trim().toLowerCase());
            assinaturas.add(new Assinatura__c(
                AssOpp__c = opportunityId,
                AutDoc__c = result.autentiqueDocumentId,
                AutSig__c = sr != null ? sr.publicId : null,
                TpSign__c = 'Signatário',
                NmSign__c = String.isNotBlank(s.name) ? s.name : s.email,
                EmlAss__c = s.email,
                StsAss__c = 'Email_Enviado',
                DtEnEm__c = DateTime.now(),
                OrdAss__c = i + 1
            ));
        }
        insert assinaturas;

        
        return result;
    }

    private static AutentiqueFilePayload buildAutentiqueFilePayload(String accessToken, String documentId) {
        try {
            Blob pdfContent = GoogleDocsService.exportGoogleDocumentAsPdf(accessToken, documentId);
            return new AutentiqueFilePayload('contrato.pdf', 'application/pdf', pdfContent);
        } catch (Exception ignored) {
            // Fallback para HTML se o export para PDF falhar em algum cenário específico.
        }
        return new AutentiqueFilePayload('contrato.html', 'text/html; charset=UTF-8',
            Blob.valueOf(GoogleDocsService.exportGoogleDocumentAsHtml(accessToken, documentId)));
    }

    private static AutentiqueApiConfig getAutentiqueApiConfig() {
        Schema.SObjectType cfgType = Schema.getGlobalDescribe().get(AUTENTIQUE_CONFIG_OBJECT);
        if (cfgType == null) {
            throw new GoogleDocsException(
                'Configuração ausente. Crie a Custom Setting Hierarchy "DatagoProjects__Autentique_Integration__c".'
            );
        }

        String soql =
            'SELECT DatagoProjects__Is_Enabled__c, DatagoProjects__Base_Url__c, DatagoProjects__Graphql_Path__c, DatagoProjects__Api_Token__c ' +
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
        cfg.enabled = (Boolean) row.get('DatagoProjects__Is_Enabled__c');
        cfg.baseUrl = (String) row.get('DatagoProjects__Base_Url__c');
        cfg.graphqlPath = (String) row.get('DatagoProjects__Graphql_Path__c');
        cfg.apiToken = (String) row.get('DatagoProjects__Api_Token__c');

        cfg.enabled = cfg.enabled != null ? cfg.enabled : true;
        cfg.baseUrl = String.isNotBlank(cfg.baseUrl) ? cfg.baseUrl : AUTENTIQUE_DEFAULT_BASE_URL;
        cfg.graphqlPath = String.isNotBlank(cfg.graphqlPath) ? cfg.graphqlPath : AUTENTIQUE_DEFAULT_GRAPHQL_PATH;

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
        List<SignerInput> signers
    ) {
        String mutation = 'mutation CreateDocumentMutation($document: DocumentInput!, $signers: [SignerInput!]!, $file: Upload!) { createDocument(document: $document, signers: $signers, file: $file) { id name signatures { public_id name email link { short_link } } } }';

        List<Object> signersList = new List<Object>();
        for (SignerInput s : signers) {
            signersList.add(new Map<String, Object>{
                'email' => s.email.trim(),
                'action' => 'SIGN',
                'name' => String.isNotBlank(s.name) ? s.name.trim() : s.email.trim()
            });
        }

        Map<String, Object> variables = new Map<String, Object>{
            'document' => new Map<String, Object>{ 'name' => documentName },
            'signers' => signersList,
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
        result.allSignerResults = new List<SignerResultInternal>();

        List<Object> signatures = (List<Object>) doc.get('signatures');
        if (signatures != null) {
            for (Object sigObj : signatures) {
                Map<String, Object> sig = (Map<String, Object>) sigObj;
                SignerResultInternal sr = new SignerResultInternal();
                sr.email = String.valueOf(sig.get('email'));
                sr.publicId = String.valueOf(sig.get('public_id'));
                if (sig.containsKey('link')) {
                    Map<String, Object> link = (Map<String, Object>) sig.get('link');
                    if (link != null) sr.signatureLink = String.valueOf(link.get('short_link'));
                }
                result.allSignerResults.add(sr);
            }
            if (!result.allSignerResults.isEmpty()) {
                result.signerPublicId = result.allSignerResults[0].publicId;
                result.signatureLink = result.allSignerResults[0].signatureLink;
                result.signerEmail = result.allSignerResults[0].email;
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

        String fileHeader =
            '--' + boundary + '\r\nContent-Disposition: form-data; name="operations"\r\n\r\n' +
            JSON.serialize(operations) + '\r\n' +
            '--' + boundary + '\r\nContent-Disposition: form-data; name="map"\r\n\r\n' +
            JSON.serialize(mapPart) + '\r\n' +
            '--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="' + filePayload.fileName + '"\r\n' +
            'Content-Type: ' + filePayload.contentType + '\r\n\r\n';

        return EncodingUtil.convertFromHex(
            EncodingUtil.convertToHex(Blob.valueOf(fileHeader)) +
            EncodingUtil.convertToHex(filePayload.content) +
            EncodingUtil.convertToHex(Blob.valueOf('\r\n--' + boundary + '--'))
        );
    }

    private static String joinUrl(String baseUrl, String path) {
        String b = baseUrl != null ? baseUrl.trim() : '';
        String p = path != null ? path.trim() : '';
        if (String.isBlank(p)) return b;
        return b.removeEnd('/') + (p.startsWith('/') ? p : '/' + p);
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
        public List<SignerResultInternal> allSignerResults;
    }

    private class SignerResultInternal {
        public String email;
        public String publicId;
        public String signatureLink;
    }

    private class AutentiqueApiConfig {
        public Boolean enabled;
        public String baseUrl;
        public String graphqlPath;
        public String apiToken;
    }
}