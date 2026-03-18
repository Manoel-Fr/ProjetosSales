public with sharing class ControllerDocumento {

    public class DocumentoWrapper {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Title;
        @AuraEnabled public String FileExtension;
        @AuraEnabled public Long ContentSize;
        @AuraEnabled public DateTime CreatedDate;
        @AuraEnabled public DateTime LastModifiedDate;
        @AuraEnabled public Id ContentVersionId;
        @AuraEnabled public String categoria;
    }

    @AuraEnabled()
    public static List<DocumentoWrapper> getDocumentos(Id accId) {
        List<DocumentoWrapper> result = new List<DocumentoWrapper>();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :accId
        ];

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        if (!docIds.isEmpty()) {
            List<ContentDocument> docs = [
                SELECT Id, Title, FileExtension, ContentSize, CreatedDate, LastModifiedDate,
                       (SELECT Id, Categoria__c FROM ContentVersions ORDER BY CreatedDate DESC LIMIT 1)
                FROM ContentDocument
                WHERE Id IN :docIds
                ORDER BY LastModifiedDate DESC
            ];

            for (ContentDocument doc : docs) {
                DocumentoWrapper w = new DocumentoWrapper();
                w.Id = doc.Id;
                w.Title = doc.Title;
                w.FileExtension = doc.FileExtension;
                w.ContentSize = doc.ContentSize;
                w.CreatedDate = doc.CreatedDate;
                w.LastModifiedDate = doc.LastModifiedDate;

                if (doc.ContentVersions != null && !doc.ContentVersions.isEmpty()) {
                    ContentVersion cv = doc.ContentVersions[0];
                    w.ContentVersionId = cv.Id;
                    w.categoria = cv.Categoria__c;
                }

                result.add(w);
            }
        }

        return result;
    }

    @AuraEnabled()
    public static void setCategoria(Id contentVersionId, String categoria) {
        ContentVersion cv = new ContentVersion(
            Id = contentVersionId,
            Categoria__c = categoria
        );
        update cv;
    }

    @AuraEnabled()
    public static String deleteDocumento(Id documentId) {
        try {
            List<ContentDocumentLink> links = [
                SELECT Id, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :documentId
            ];
            delete [SELECT Id FROM ContentDocument WHERE Id = :documentId];

            return 'success';
        } catch (Exception e) {
            return 'erro:' + e.getMessage();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<String> getCategoriasPicklist() {
        List<String> categorias = new List<String>();
        Schema.DescribeFieldResult fieldResult = ContentVersion.Categoria__c.getDescribe();
        List<Schema.PicklistEntry> entries = fieldResult.getPicklistValues();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                categorias.add(entry.getValue());
            }
        }
        return categorias;
    }
}
  //sf project deploy start  --metadata ApexClass:ControllerDocumento  --metadata ApexClass:TestControllerDocuments   -l RunSpecifiedTests -t TestControllerDocuments -o azulProd