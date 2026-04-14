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

        Map<Id, ContentVersion> cvMap = new Map<Id, ContentVersion>(
            [SELECT Id FROM ContentVersion WHERE Id IN :idList]
        );

        for (String cvId : idList) {
            if (cvMap.containsKey(cvId)) {
                PhotoWrapper pw = new PhotoWrapper();
                pw.imageUrl     = '/sfc/servlet.shepherd/version/download/' + cvId;
                photos.add(pw);
            }
        }
    }
}
