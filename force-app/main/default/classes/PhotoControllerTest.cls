@isTest
public with sharing class PhotoControllerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title       = 'foto_teste',
            PathOnClient = 'foto_teste.jpg',
            VersionData  = Blob.valueOf('fake_image_data'),
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId    = acc.Id,
            ShareType         = 'V'
        );
    }

    @isTest
    static void testGetFileInfo() {
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title = 'foto_teste'];

        Test.startTest();
        List<PhotoController.FileInfo> result = PhotoController.getFileInfo(
            new List<String>{ cvs[0].Id }
        );
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('foto_teste', result[0].title);
        System.assert(result[0].previewUrl.contains(cvs[0].Id));
    }

    @isTest
    static void testGetFileInfoEmpty() {
        Test.startTest();
        List<PhotoController.FileInfo> result = PhotoController.getFileInfo(new List<String>());
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetLinkedImageFiles() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        List<PhotoController.FileInfo> result = PhotoController.getLinkedImageFiles(acc.Id);
        Test.stopTest();

        System.assertEquals(1, result.size());
        System.assertEquals('foto_teste', result[0].title);
    }

    @isTest
    static void testGetLinkedImageFilesNullId() {
        Test.startTest();
        List<PhotoController.FileInfo> result = PhotoController.getLinkedImageFiles(null);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGetLinkedImageFilesNoFiles() {
        Account acc = new Account(Name = 'Empty Account');
        insert acc;

        Test.startTest();
        List<PhotoController.FileInfo> result = PhotoController.getLinkedImageFiles(acc.Id);
        Test.stopTest();

        System.assertEquals(0, result.size());
    }

    @isTest
    static void testGeneratePDF() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title = 'foto_teste'];

        Test.startTest();
        PhotoController.generatePDF(
            new List<String>{ cvs[0].Id },
            acc.Id
        );
        Test.stopTest();

        List<ContentVersion> pdfCv = [
            SELECT Id, Title FROM ContentVersion WHERE Title LIKE 'PDF FOTOS%'
        ];
        System.assertEquals(1, pdfCv.size());
        //System.assert(pdfCv[0].Title.contains('Test Account'));
    }

    @isTest
    static void testGeneratePDFBlankRecordId() {
        Test.startTest();
        try {
            PhotoController.generatePDF(new List<String>(), '');
            System.assert(false, 'Deveria ter lançado exceção');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('precisa estar em uma página de registro'));
        }
        Test.stopTest();
    }
}