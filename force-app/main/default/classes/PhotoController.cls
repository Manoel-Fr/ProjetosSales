public with sharing class PhotoController {
  // chamado após upload para buscar info das fotos                                                                                      
  @AuraEnabled
  public static List<FileInfo> getFileInfo(List<String> contentVersionIds) {                                                             
      List<FileInfo> result = new List<FileInfo>();                                                                                      

      for (ContentVersion cv : [                                                                                                         
          SELECT Id, Title, FileType, ContentDocumentId
          FROM ContentVersion
          WHERE Id IN :contentVersionIds
      ]) {
          FileInfo fi       = new FileInfo();
          fi.id             = cv.Id;
          fi.title          = cv.Title;
          fi.previewUrl     = '/sfc/servlet.shepherd/version/download/' + cv.Id;
          result.add(fi);                                                                                                                
      }
                                                                                                                                         
      return result;
  }

  // gera o PDF e anexa ao registro
  @AuraEnabled
  public static void generatePDF(List<String> orderedIds, String recordId) {
      if (String.isBlank(recordId)) {
          throw new AuraHandledException('Este componente precisa estar em uma página de registro.');
      }

      // busca o nome do registro para usar no título do PDF
      SObject record = Database.query(
          'SELECT Name FROM ' + Id.valueOf(recordId).getSObjectType() + ' WHERE Id = :recordId'
      );

      PageReference pdfPage = Page.PhotosPDF;
      pdfPage.getParameters().put('ids', String.join(orderedIds, ','));

      Blob pdfBlob;
      if (Test.isRunningTest()) {
          pdfBlob = Blob.valueOf('fake_pdf_content');
      } else {
          pdfBlob = pdfPage.getContentAsPDF();
      }

      ContentVersion cv = new ContentVersion();
      cv.Title          = 'PDF FOTOS ' + (String) record.get('Name');
      cv.PathOnClient   = cv.Title + '.pdf';
      cv.VersionData    = pdfBlob;
      cv.IsMajorVersion = true;
      insert cv;

      // busca o ContentDocumentId gerado após o insert
      String contentDocumentId = [
          SELECT ContentDocumentId
          FROM ContentVersion
          WHERE Id = :cv.Id
      ].ContentDocumentId;

      // vincula o PDF ao registro
      ContentDocumentLink cdl = new ContentDocumentLink();
      cdl.ContentDocumentId   = contentDocumentId;
      cdl.LinkedEntityId      = recordId;
      cdl.ShareType           = 'V';
      insert cdl;
  }           

  public class FileInfo {
      @AuraEnabled public String id         { get; set; }
      @AuraEnabled public String title      { get; set; }
      @AuraEnabled public String previewUrl { get; set; }
  }                                                                                                                                      
}

