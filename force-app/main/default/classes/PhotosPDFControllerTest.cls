@isTest
public with sharing class PhotosPDFControllerTest {

    @isTest
    static void testConstructorWithIds() {
        ContentVersion cv = new ContentVersion(
            Title        = 'foto_pdf_test',
            PathOnClient = 'foto_pdf_test.jpg',
            VersionData  = Blob.valueOf('fake_image_data'),
            IsMajorVersion = true
        );
        insert cv;

        cv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];

        PageReference page = Page.PhotosPDF;
        page.getParameters().put('ids', cv.Id);
        Test.setCurrentPage(page);

        Test.startTest();
        PhotosPDFController ctrl = new PhotosPDFController();
        Test.stopTest();

        System.assertEquals(1, ctrl.photos.size());
        System.assert(ctrl.photos[0].imageUrl.contains(cv.Id));
    }

    @isTest
    static void testConstructorNoIds() {
        PageReference page = Page.PhotosPDF;
        Test.setCurrentPage(page);

        Test.startTest();
        PhotosPDFController ctrl = new PhotosPDFController();
        Test.stopTest();

        System.assertEquals(0, ctrl.photos.size());
    }

    @isTest
    static void testConstructorInvalidId() {
        PageReference page = Page.PhotosPDF;
        page.getParameters().put('ids', 'agsfevw');
        Test.setCurrentPage(page);

        Test.startTest();
        PhotosPDFController ctrl = new PhotosPDFController();
        Test.stopTest();

        System.assertEquals(0, ctrl.photos.size());
    }

    @isTest
    static void testConstructorMultipleIds() {
        ContentVersion cv1 = new ContentVersion(
            Title        = 'foto1',
            PathOnClient = 'foto1.jpg',
            VersionData  = Blob.valueOf('img1')
        );
        ContentVersion cv2 = new ContentVersion(
            Title        = 'foto2',
            PathOnClient = 'foto2.jpg',
            VersionData  = Blob.valueOf('img2')
        );
        insert new List<ContentVersion>{ cv1, cv2 };

        List<Id> ids = new List<Id>();
        for (ContentVersion cv : [SELECT Id FROM ContentVersion WHERE Title IN ('foto1','foto2')]) {
            ids.add(cv.Id);
        }

        PageReference page = Page.PhotosPDF;
        page.getParameters().put('ids', String.join(ids, ','));
        Test.setCurrentPage(page);

        Test.startTest();
        PhotosPDFController ctrl = new PhotosPDFController();
        Test.stopTest();

        System.assertEquals(2, ctrl.photos.size());
    }
}