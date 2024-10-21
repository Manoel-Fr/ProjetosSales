public with sharing class UltimosDias {
  @AuraEnabled
  public static List<Object> busDias (String moeda, Integer numeroDias) { 
   //    moeda = moeda.toUpperCase();
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
public static  void saveQuo (String moeda, Decimal cotacao, Date Data)  {

List<Quotacao_diaria__c> quotacao = [SELECT Moeda__c, Cotacao__c,Data__c,Externald__c FROM Quotacao_diaria__c WHERE Moeda__c = :moeda];



     
  for(Quotacao_diaria__c q : quotacao)  {

     q.Data__c = Data;
    q.Cotacao__c = cotacao;
  }
     
      Quotacao_diaria__c Qnew = new Quotacao_diaria__c ();
       
 
      Qnew.Moeda__c = moeda;
      Qnew.Cotacao__c = cotacao;
      Qnew.Data__c = Data;
     

      if(quotacao.isEmpty()){

        quotacao.add(Qnew);
      }else{
        Qnew.Externald__c = quotacao[0].Externald__c;
      }
    
      upsert quotacao ;
      
  }
}



    
