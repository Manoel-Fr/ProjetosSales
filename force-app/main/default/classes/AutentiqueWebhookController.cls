@RestResource(urlMapping='/webhooks')
global without sharing class AutentiqueWebhookController {

    @HttpPost
    global static void handleWebhook() {
        RestResponse res = RestContext.response;
        res.statusCode = 200;

        try {
            String body = RestContext.request.requestBody.toString();
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(body);

            Map<String, Object> event = (Map<String, Object>) payload.get('event');
            if (event == null) return;

            String eventType = (String) event.get('type');
            Map<String, Object> data = (Map<String, Object>) event.get('data');
            if (data == null) return;

            String docId = extractDocumentId(data, eventType);
            if (String.isBlank(docId)) return;

            if (eventType == 'signature.viewed' || eventType == 'signature.accepted' ||
                eventType == 'signature.created' || eventType == 'signature.rejected' ||
                eventType == 'document.finished') {
                publishEvent(docId, eventType, data);
            }

        } catch (Exception e) {
            res.responseBody = Blob.valueOf(e.getMessage());
        }
    }

    private static String extractDocumentId(Map<String, Object> data, String eventType) {
        if (eventType != null && eventType.startsWith('signature.')) {
            return (String) data.get('document');
        }
        return (String) data.get('id');
    }

    private static void publishEvent(String docId, String eventType, Map<String, Object> data) {
        AutentiqueWebhookEvent__e evt = new AutentiqueWebhookEvent__e();
        evt.DocId__c = docId;
        evt.EventType__c = eventType;
        String rawPublicId = (String) data.get('public_id');
        evt.SigPublicId__c = rawPublicId != null ? rawPublicId.replace('-', '') : null;
        evt.ViewedDt__c = (String) data.get('viewed');
        evt.SignedDt__c = (String) data.get('signed');
        evt.RejectedDt__c = (String) data.get('rejected');

        if (eventType == 'signature.viewed') {
            List<Object> events = (List<Object>) data.get('events');
            if (events != null && !events.isEmpty()) {
                Map<String, Object> lastEvt = (Map<String, Object>) events[events.size() - 1];
                if (lastEvt != null && lastEvt.containsKey('ip')) {
                    evt.IpAddress__c = (String) lastEvt.get('ip');
                }
            }
        }

        Database.SaveResult sr = EventBus.publish(evt);
        if (!sr.isSuccess()) {
            String errs = '';
            for (Database.Error e : sr.getErrors()) {
                errs += e.getStatusCode() + ': ' + e.getMessage() + ' | ';
            }
            throw new AuraHandledException('EventBus.publish failed: ' + errs);
        }
    }
}