public with sharing class buscaMoedas {
  @AuraEnabled
  public static Map<String,Decimal> pegarMoedas() {
   HttpRequest req = new HttpRequest();
   req.setEndpoint('https://economia.awesomeapi.com.br/last/USD-BRL,EUR-BRL,BTC-BRL');
   req.setMethod('GET');

   Http http = new Http();
   HTTPResponse res = http.send(req);
      
   if(res.getStatusCode() == 200) {

     Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
     Map<String, Decimal> moedas = new map <String, Decimal>();

            Map<String, Object> dolar = (Map<String, Object>) result.get('USDBRL');
            Decimal bidDolar = Decimal.valueOf((String) dolar.get('bid'));
     moedas.put('USD',bidDolar);
            Map<String, Object> euro = (Map<String, Object>) result.get('EURBRL');
            Decimal bidEuro = Decimal.valueOf((String) euro.get('bid'));
     moedas.put('EUR',bidEuro);
           Map<String, Object> btc = (Map<String, Object>) result.get('BTCBRL');
           Decimal bidBtc = Decimal.valueOf((String) btc.get('bid'));
     moedas.put('BTC',bidBtc);
      return moedas;
 } else{
   return null;

 }
}
}   