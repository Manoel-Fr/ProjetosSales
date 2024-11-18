public with sharing class UltimosDias {
  @AuraEnabled
  public static List<Object> busDias (String moeda, Integer numeroDias) { 
       moeda = moeda.toUpperCase();
       String url = 'https://economia.awesomeapi.com.br/json/daily/'+ moeda +'-BRL/' + numeroDias ;
HttpRequest req = new HttpRequest();
req.setEndpoint(url);
req.setMethod('GET');

Http http = new Http();
HTTPResponse res = http.send(req);

if(res.getStatusCode() == 200) {
List<Object> result = (List<Object>) JSON.deserializeUntyped(res.getBody());

      return result;
 } else {
   return null;

   }
    
   
} 
 
 

@AuraEnabled
public static  void saveQuo (List<Map<String, Object>> cotacoes )  {

List<Quotacao_diaria__c> quotacao = new List<Quotacao_diaria__c>();

 for(Map<String, Object> cotacao : cotacoes) {
  Quotacao_diaria__c quo = new Quotacao_diaria__c();
  quo.Moeda__c = (String) cotacao.get('code');
  quo.Cotacao__c = Decimal.valueOf((String) cotacao.get('bid'));
  quo.Data__c =  Date.valueOf((String) cotacao.get('create_date'));
  quo.ExternalId__c = (String) cotacao.get('code') + '-' + (String) cotacao.get('create_date');
   quotacao.add(quo);
 }

  upsert  quotacao ExternalId__c;

    }
 }
    
