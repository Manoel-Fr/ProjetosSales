public with sharing class AssinaturasController {
    
    @AuraEnabled
    public static List<Assinatura__c> getAssinaturas(String opportunityId) {
        return [
            SELECT Id, Name, AssOpp__c, AutDoc__c, AutSig__c, TpSign__c, NmSign__c, EmlAss__c, StsAss__c, DtAssn__c, DtEnEm__c, DtRecs__c, DtAbDc__c, IpAbrt__c 
            FROM Assinatura__c
            WHERE AssOpp__c = :opportunityId];
    }   


}