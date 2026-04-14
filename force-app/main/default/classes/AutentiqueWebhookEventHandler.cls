public without sharing class AutentiqueWebhookEventHandler {

    public static void handle(List<AutentiqueWebhookEvent__e> events) {
        for (AutentiqueWebhookEvent__e evt : events) {
            if (String.isBlank(evt.DocId__c) || String.isBlank(evt.EventType__c)) continue;
            updateAssinatura(evt);
        }
    }

    private static void updateAssinatura(AutentiqueWebhookEvent__e evt) {
        List<Assinatura__c> assinaturas;

        if (String.isNotBlank(evt.SigPublicId__c)) {
            assinaturas = [
                SELECT Id, StsAss__c, DtAssn__c, DtRecs__c, DtAbDc__c, IpAbrt__c, AutSig__c
                FROM Assinatura__c
                WHERE AutDoc__c = :evt.DocId__c AND AutSig__c = :evt.SigPublicId__c
                LIMIT 1
            ];
        }

        if ((assinaturas == null || assinaturas.isEmpty())) {
            assinaturas = [
                SELECT Id, StsAss__c, DtAssn__c, DtRecs__c, DtAbDc__c, IpAbrt__c, AutSig__c
                FROM Assinatura__c
                WHERE AutDoc__c = :evt.DocId__c AND TpSign__c = 'Signatário'
                ORDER BY OrdAss__c ASC NULLS LAST
                LIMIT 1
            ];
        }

        if (assinaturas.isEmpty()) return;

        Assinatura__c ass = assinaturas[0];
        if (String.isNotBlank(evt.SigPublicId__c) && String.isBlank(ass.AutSig__c)) {
            ass.AutSig__c = evt.SigPublicId__c;
        }
        DateTime now = DateTime.now();

        if (evt.EventType__c == 'signature.accepted' || evt.EventType__c == 'signature.created') {
            ass.StsAss__c = 'Assinado';
            ass.DtAssn__c = parseDateTime(evt.SignedDt__c);
        } else if (evt.EventType__c == 'signature.viewed') {
            ass.StsAss__c = 'Documento_Aberto';
            ass.DtAbDc__c = parseDateTime(evt.ViewedDt__c);
            if (String.isNotBlank(evt.IpAddress__c)) {
                ass.IpAbrt__c = evt.IpAddress__c;
            }
        } else if (evt.EventType__c == 'signature.rejected') {
            ass.StsAss__c = 'Recusado';
            ass.DtRecs__c = parseDateTime(evt.RejectedDt__c);
        } else if (evt.EventType__c == 'document.finished') {
            ass.StsAss__c = 'Assinado';
            if (ass.DtAssn__c == null) ass.DtAssn__c = now;
        }

        update ass;
    }

    private static DateTime parseDateTime(String dtStr) {
        if (String.isBlank(dtStr)) return null;
        try {
            String s = dtStr.replace('Z', '').replace('T', ' ');
            return DateTime.valueOfGmt(s.substring(0, Math.min(s.length(), 19)));
        } catch (Exception e) {
            return null;
        }
    }
}