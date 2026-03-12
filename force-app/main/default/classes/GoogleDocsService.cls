/**
 * Serviço de operações com Google Docs e Google Drive.
 * Cria documentos a partir de oportunidades e exporta para HTML/PDF.
 */
public with sharing class GoogleDocsService {

    private static final String GOOGLE_DOCS_API  = 'https://docs.googleapis.com/v1/documents';
    private static final String GOOGLE_DRIVE_API = 'https://www.googleapis.com/drive/v3/files';
    private static final String PRODUCT_PLACEHOLDER = '{{LISTA_PRODUTOS}}';
    private static final Integer PRODUCT_TABLE_COLS = 5;

    @AuraEnabled
    public static String createDocumentFromOpportunity(String opportunityId) {
        String accessToken = GoogleAuthService.refreshAccessToken();
        Google_Credentials__c creds = GoogleAuthService.getCredentials();
        String templateId = creds != null ? creds.Template_Document_Id__c : null;

        if (String.isBlank(templateId)) {
            throw new GoogleDocsException(
                'Configure o ID do documento modelo em Configurações > Google Credentials > Template Document Id. ' +
                'Crie um documento no Google Docs com variáveis no formato {{NOME_VARIAVEL}}.'
            );
        }

        Opportunity opp = [
            SELECT Id, Name, Amount, StageName, Description, CloseDate,
                   AccountId, Account.Name, Account.BillingStreet,
                   Account.BillingCity, Account.BillingState, Account.BillingPostalCode
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        String tituloDoc = 'Contrato - ' + (opp.Account != null ? opp.Account.Name : opp.Name) + ' - ' + opp.Name;

        String docId;
        try {
            docId = copyTemplateDocument(accessToken, templateId, tituloDoc);
        } catch (GoogleDocsException e) {
            if (e.getMessage() != null && e.getMessage().contains('PERMISSION_DENIED')) {
                throw new GoogleDocsException(
                    'Permissão negada ao copiar o documento. Faça o seguinte: 1) No Google Cloud Console, ative a API "Google Drive API" no mesmo projeto das credenciais. ' +
                    '2) Em account.google.com, em Segurança > Acesso de terceiros, revogue o acesso do app e depois clique em "Conectar com Google" novamente na página da Oportunidade.'
                );
            }
            throw e;
        }

        List<OpportunityLineItem> productItems = [
            SELECT Quantity, UnitPrice, TotalPrice, PricebookEntry.Name
            FROM OpportunityLineItem
            WHERE OpportunityId = :opp.Id
            ORDER BY CreatedDate
        ];

        Map<String, String> variaveis = buildReplacementMap(opp);
        replaceVariablesInDocument(accessToken, docId, variaveis, productItems);

        return 'https://docs.google.com/document/d/' + docId + '/edit';
    }

    /**
     * Exporta um documento do Google Docs para HTML.
     * Usado pelo AutentiqueService para envio à plataforma de assinatura.
     */
    public static String exportGoogleDocumentAsHtml(String accessToken, String documentId) {
        Blob htmlBlob = exportGoogleDocumentAsBlob(accessToken, documentId, 'text/html');
        String htmlContent = htmlBlob != null ? htmlBlob.toString() : null;
        if (String.isBlank(htmlContent)) {
            throw new GoogleDocsException('Não foi possível exportar o documento para HTML.');
        }
        return htmlContent;
    }

    /**
     * Exporta um documento do Google Docs para PDF.
     * Preferível para assinatura porque preserva o layout final do documento.
     */
    public static Blob exportGoogleDocumentAsPdf(String accessToken, String documentId) {
        Blob pdfBlob = exportGoogleDocumentAsBlob(accessToken, documentId, 'application/pdf');
        if (pdfBlob == null || pdfBlob.size() == 0) {
            throw new GoogleDocsException('Não foi possível exportar o documento para PDF.');
        }
        return pdfBlob;
    }

    /**
     * Extrai o ID do documento a partir da URL do Google Docs.
     */
    public static String extractDocumentIdFromUrl(String documentUrl) {
        if (String.isBlank(documentUrl)) {
            throw new GoogleDocsException('URL do documento inválida.');
        }
        String marker = '/d/';
        Integer start = documentUrl.indexOf(marker);
        if (start < 0) {
            throw new GoogleDocsException('Não foi possível identificar o ID do documento.');
        }
        start += marker.length();
        Integer endIdx = documentUrl.indexOf('/', start);
        if (endIdx < 0) endIdx = documentUrl.length();
        return documentUrl.substring(start, endIdx);
    }

    private static Blob exportGoogleDocumentAsBlob(String accessToken, String documentId, String mimeType) {
        String endpoint =
            GOOGLE_DRIVE_API + '/' + documentId +
            '/export?mimeType=' + EncodingUtil.urlEncode(mimeType, 'UTF-8');
        HttpResponse res = GoogleApiClient.sendRequest(endpoint, 'GET', accessToken, null, null);
        return res.getBodyAsBlob();
    }

    private static String copyTemplateDocument(String token, String templateFileId, String newDocumentName) {
        String body = JSON.serialize(new Map<String, Object>{ 'name' => newDocumentName });
        String url = GOOGLE_DRIVE_API + '/' + templateFileId + '/copy?supportsAllDrives=true';
        HttpResponse res = GoogleApiClient.sendRequest(url, 'POST', token, 'application/json', body);
        Map<String, Object> json = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) json.get('id');
    }

    private static Map<String, String> buildReplacementMap(Opportunity opp) {
        Map<String, String> m = new Map<String, String>();
        m.put('NOME_OPORTUNIDADE', val(opp.Name));
        m.put('VALOR', money(opp.Amount));
        m.put('VALOR_MENSAL', money(opp.Amount));
        m.put('ESTAGIO', val(opp.StageName));
        m.put('DATA_FECHAMENTO', opp.CloseDate != null ? opp.CloseDate.format() : '');
        m.put('DATA_ASSINATURA', opp.CloseDate != null ? opp.CloseDate.format() : '');
        m.put('DESCRICAO', val(opp.Description));
        m.put('RAZAO_SOCIAL', val(opp.Account.Name != null ? opp.Account.Name : ''));
        m.put('ENDERECO', val(opp.Account.BillingStreet != null ? opp.Account.BillingStreet : ''));
        m.put('CIDADE_UF',
            val(opp.Account.BillingCity != null ? opp.Account.BillingCity : '') +
            (String.isNotBlank(opp.Account.BillingState) ? '/' + opp.Account.BillingState : '')
        );
        m.put('CEP', val(opp.Account.BillingPostalCode != null ? opp.Account.BillingPostalCode : ''));
        m.put('NUMERO', '');
        m.put('BAIRRO', '');
        m.put('CNPJ', '');
        m.put('NOME_REPRESENTANTE', '');
        m.put('CPF', '');
        return m;
    }

    private static void replaceVariablesInDocument(String token, String docId, Map<String, String> variaveis, List<OpportunityLineItem> productItems) {
        List<Map<String, Object>> requests = new List<Map<String, Object>>();

        for (String nomeVar : variaveis.keySet()) {
            String placeholder = '{{' + nomeVar + '}}';
            String valor = variaveis.get(nomeVar) != null ? variaveis.get(nomeVar) : '';

            requests.add(new Map<String, Object>{
                'replaceAllText' => new Map<String, Object>{
                    'replaceText' => valor,
                    'containsText' => new Map<String, Object>{
                        'text' => placeholder,
                        'matchCase' => false
                    }
                }
            });
        }

        sendBatchUpdate(token, docId, requests);

        Map<String, Object> doc = getDocument(token, docId);
        Map<String, Object> body = (Map<String, Object>) doc.get('body');
        if (body == null) return;

        List<Integer> range = findPlaceholderRange(body, PRODUCT_PLACEHOLDER);
        Integer startIdx = range != null ? range[0] : getBodyEndIndex(body);
        Integer endIdx = range != null ? range[1] : null;
        insertProductsTable(token, docId, startIdx, endIdx, productItems);
    }

    private static void insertProductsTable(String token, String docId, Integer startIdx, Integer endIdx, List<OpportunityLineItem> productItems) {
        List<OpportunityLineItem> items = productItems != null ? productItems : new List<OpportunityLineItem>();
        Integer numRows = 1 + items.size();

        List<Map<String, Object>> tableRequests = new List<Map<String, Object>>();
        if (endIdx != null) {
            tableRequests.add(new Map<String, Object>{
                'deleteContentRange' => new Map<String, Object>{
                    'range' => new Map<String, Object>{
                        'startIndex' => startIdx,
                        'endIndex' => endIdx
                    }
                }
            });
        }
        tableRequests.add(new Map<String, Object>{
            'insertTable' => new Map<String, Object>{
                'rows' => numRows,
                'columns' => PRODUCT_TABLE_COLS,
                'location' => new Map<String, Object>{ 'index' => startIdx }
            }
        });
        sendBatchUpdate(token, docId, tableRequests);

        Map<String, Object> doc2 = getDocument(token, docId);
        List<Integer> cellIndices = collectTableCellIndices(doc2, startIdx);
        if (cellIndices.isEmpty()) return;

        List<String> cellTexts = new List<String>{ 'Item', 'Produto', 'Qtd', 'Valor unit.', 'Total' };
        Integer idx = 1;
        for (OpportunityLineItem item : items) {
            cellTexts.add(String.valueOf(idx));
            cellTexts.add(val(item.PricebookEntry.Name));
            cellTexts.add(String.valueOf(item.Quantity));
            cellTexts.add(money(item.UnitPrice));
            cellTexts.add(money(item.TotalPrice));
            idx++;
        }

        Map<Integer, String> byIndex = new Map<Integer, String>();
        Integer n = Math.min(cellIndices.size(), cellTexts.size());
        for (Integer i = 0; i < n; i++) {
            byIndex.put(cellIndices[i], cellTexts[i]);
        }
        List<Integer> sorted = new List<Integer>(byIndex.keySet());
        sorted.sort();

        List<Map<String, Object>> insertRequests = new List<Map<String, Object>>();
        for (Integer i = sorted.size() - 1; i >= 0; i--) {
            Integer pos = sorted[i];
            insertRequests.add(new Map<String, Object>{
                'insertText' => new Map<String, Object>{
                    'location' => new Map<String, Object>{ 'index' => pos },
                    'text' => byIndex.get(pos)
                }
            });
        }
        sendBatchUpdate(token, docId, insertRequests);
    }

    private static Map<String, Object> getDocument(String token, String docId) {
        HttpResponse res = GoogleApiClient.sendRequest(GOOGLE_DOCS_API + '/' + docId, 'GET', token, null, null);
        return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
    }

    // Procura {{LISTA_PRODUTOS}} no documento e retorna [inicio, fim] do texto encontrado.
    // Retorna null se o placeholder não existir no template.
    private static List<Integer> findPlaceholderRange(Map<String, Object> body, String placeholder) {
        for (Object el : docList(body, 'content')) {
            Map<String, Object> elem = (Map<String, Object>) el;
            if (!elem.containsKey('paragraph')) continue;

            for (Object pe : docList((Map<String, Object>) elem.get('paragraph'), 'elements')) {
                Map<String, Object> peMap = (Map<String, Object>) pe;
                if (!peMap.containsKey('textRun')) continue;

                String text = (String) ((Map<String, Object>) peMap.get('textRun')).get('content');
                if (text == null || !text.contains(placeholder)) continue;

                Integer start = GoogleApiClient.toInt(peMap.get('startIndex'));
                if (start == null) continue;

                Integer offset = text.indexOf(placeholder);
                return new List<Integer>{ start + offset, start + offset + placeholder.length() };
            }
        }
        return null;
    }

    // Retorna o índice do último caractere do documento.
    // Usado como posição de inserção quando {{LISTA_PRODUTOS}} não existe no template.
    private static Integer getBodyEndIndex(Map<String, Object> body) {
        Integer maxEnd = 1;
        for (Object el : docList(body, 'content')) {
            Integer endIdx = GoogleApiClient.toInt(((Map<String, Object>) el).get('endIndex'));
            if (endIdx != null && endIdx > maxEnd) maxEnd = endIdx;
        }
        return maxEnd;
    }

    // Após inserir a tabela vazia, percorre as células e coleta o startIndex de cada uma.
    // Esses índices são usados para preencher as células com texto depois.
    private static List<Integer> collectTableCellIndices(Map<String, Object> doc, Integer tableStartIndex) {
        List<Integer> indices = new List<Integer>();
        Map<String, Object> body = (Map<String, Object>) doc.get('body');
        if (body == null) return indices;

        for (Object el : docList(body, 'content')) {
            Map<String, Object> elem = (Map<String, Object>) el;
            if (!elem.containsKey('table')) continue;

            Integer elemStart = GoogleApiClient.toInt(elem.get('startIndex'));
            if (elemStart == null || (elemStart != tableStartIndex && elemStart != tableStartIndex + 1)) continue;

            for (Object rowObj : docList((Map<String, Object>) elem.get('table'), 'tableRows')) {
                for (Object cellObj : docList((Map<String, Object>) rowObj, 'tableCells')) {
                    Integer idx = cellFirstElementIndex((Map<String, Object>) cellObj);
                    if (idx != null) indices.add(idx);
                }
            }
            break;
        }
        return indices;
    }

    // Retorna o startIndex do primeiro elemento de texto dentro de uma célula da tabela.
    private static Integer cellFirstElementIndex(Map<String, Object> cell) {
        List<Object> cellContent = docList(cell, 'content');
        if (cellContent.isEmpty()) return null;
        Map<String, Object> firstBlock = (Map<String, Object>) cellContent[0];
        if (!firstBlock.containsKey('paragraph')) return null;
        List<Object> elements = docList((Map<String, Object>) firstBlock.get('paragraph'), 'elements');
        if (elements.isEmpty()) return null;
        return GoogleApiClient.toInt(((Map<String, Object>) elements[0]).get('startIndex'));
    }

    // Atalho seguro para pegar uma lista de qualquer nó do documento sem risco de NullPointerException.
    private static List<Object> docList(Map<String, Object> node, String key) {
        if (node == null) return new List<Object>();
        Object v = node.get(key);
        return v != null ? (List<Object>) v : new List<Object>();
    }

    private static void sendBatchUpdate(String token, String docId, List<Map<String, Object>> requests) {
        if (requests == null || requests.isEmpty()) return;
        GoogleApiClient.sendRequest(
            GOOGLE_DOCS_API + '/' + docId + ':batchUpdate',
            'POST',
            token,
            'application/json',
            JSON.serialize(new Map<String, Object>{ 'requests' => requests })
        );
    }

    private static String money(Decimal d) {
        return d == null ? 'R$ 0,00' : 'R$ ' + d.setScale(2).format();
    }

    private static String val(String s) {
        return s == null ? '' : s;
    }
}
