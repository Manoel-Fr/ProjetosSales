public with sharing class PhotosPDFController {

    public List<PhotoWrapper> photos { get; set; }

    public class PhotoWrapper {
        public String imageUrl { get; set; }
    }

    public PhotosPDFController() {
        photos = new List<PhotoWrapper>();

        String idsParam = ApexPages.currentPage().getParameters().get('ids');
        if (String.isBlank(idsParam)) return;

        List<String> idList = idsParam.split(',');

        List<Id> validIds = new List<Id>();
        for (String idStr : idList) {
            try {
                validIds.add(Id.valueOf(idStr));
            } catch (StringException e) {
                // ignora IDs com formato inválido
            }
        }
        if (validIds.isEmpty()) return;

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>(
            [SELECT Id FROM ContentVersion WHERE Id IN :validIds]
        );

        for (Id cvId : validIds) {
            if (cvMap.containsKey(cvId)) {
                PhotoWrapper pw = new PhotoWrapper();
                pw.imageUrl     = '/sfc/servlet.shepherd/version/download/' + cvId;
                photos.add(pw);
            }
        }
    }
}