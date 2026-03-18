@isTest
public with sharing class TestControllerDocuments {

    @isTest
    public static void testGetDocumentos() {

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Test Content Version',
            PathOnClient = 'TestContentVersion.pdf',
            VersionData = Blob.valueOf('Test Content Version'),
            IsMajorVersion = true
        );
        insert cv;

        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = acc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;

        Test.startTest();
        List<ControllerDocumento.DocumentoWrapper> docs = ControllerDocumento.getDocumentos(acc.Id);
        Test.stopTest();

        System.assertEquals(1, docs.size());
        System.assertEquals('Test Content Version', docs[0].Title);
        System.assertEquals('pdf', docs[0].FileExtension);
    }

    @isTest
    static void testDeleteDocumento() {
        Account acc = new Account(Name = 'Conta Teste');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Teste.pdf',
            PathOnClient = 'Teste.pdf',
            VersionData = Blob.valueOf('arquivo de teste')
        );
        insert cv;

        Id documentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = documentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Test.startTest();
        String result = ControllerDocumento.deleteDocumento(documentId);
        Test.stopTest();

        System.assertEquals('success', result);

        List<ContentDocument> deletedDoc = [
            SELECT Id FROM ContentDocument WHERE Id = :documentId
        ];
        System.assertEquals(0, deletedDoc.size(), 'Documento deve ter sido deletado');
    }

    @isTest
    static void testSetCategoria() {
        ContentVersion cv = new ContentVersion(
            Title = 'Etiqueta.jpg',
            PathOnClient = 'Etiqueta.jpg',
            VersionData = Blob.valueOf('imagem de etiqueta')
        );
        insert cv;

        Id cvId = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id].Id;

        Test.startTest();
        ControllerDocumento.setCategoria(cvId, 'Etiqueta do Produto');
        Test.stopTest();

        ContentVersion updated = [SELECT Categoria__c FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals('Etiqueta do Produto', updated.Categoria__c, 'Categoria deve ser Etiqueta do Produto');
    }

    @isTest
    static void testGetCategoriasPicklist() {
        Test.startTest();
        List<String> categorias = ControllerDocumento.getCategoriasPicklist();
        System.debug('categorias: ' + categorias);
        Test.stopTest();
      
    }
}
